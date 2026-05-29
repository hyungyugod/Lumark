-- Lumark — Supabase schema (accounts + credits, Path A)
--
-- 실행: Supabase 대시보드 → SQL Editor에 통째로 붙여넣고 Run.
-- 확정 스펙: Apple 로그인만 / 가입 시 + 매월 무료 100 크레딧 /
--           OCR 1·페이지, 퀴즈 2·회 / 본인 키 = 무제한(여기 안 거침) / 유료 없음.
-- 크레딧 변경은 전부 service_role(Worker)이 호출하는 RPC로만. 클라이언트는 읽기만.

-- ── 1) profiles: auth 유저당 1행, 크레딧 잔액 보관 ──────────────────────────
create table if not exists public.profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  credits        integer     not null default 100,
  monthly_grant  integer     not null default 100,
  last_refill_at timestamptz not null default now(),
  created_at     timestamptz not null default now()
);

-- ── 2) credit_ledger: 모든 크레딧 변동 감사 로그(지급/차감/환불/충전) ───────────
create table if not exists public.credit_ledger (
  id         bigint generated always as identity primary key,
  user_id    uuid    not null references auth.users(id) on delete cascade,
  delta      integer not null,            -- +지급/충전/환불, -차감
  reason     text    not null,            -- 'signup' | 'ocr' | 'quiz' | 'refund' | 'monthly_refill'
  ref        text,                        -- 예: note id / request id
  created_at timestamptz not null default now()
);
create index if not exists credit_ledger_user_idx
  on public.credit_ledger(user_id, created_at desc);

-- ── 3) RLS: 본인 행 읽기만. 쓰기 정책 없음 → 클라이언트는 크레딧 못 바꿈 ──────────
alter table public.profiles      enable row level security;
alter table public.credit_ledger enable row level security;

drop policy if exists "own profile read" on public.profiles;
create policy "own profile read" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "own ledger read" on public.credit_ledger;
create policy "own ledger read" on public.credit_ledger
  for select using (auth.uid() = user_id);

-- ── 4) 신규 가입 트리거: profile 생성 + 가입 보너스 100 ───────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, credits) values (new.id, 100);
  insert into public.credit_ledger (user_id, delta, reason)
       values (new.id, 100, 'signup');
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── 5) spend_credits: 원자적 검사+차감. 새 잔액 반환, 부족하면 -1 ─────────────
--    (단일 UPDATE의 WHERE credits >= amount 라 동시성 레이스 없음.)
create or replace function public.spend_credits(
  p_user uuid, p_amount int, p_reason text, p_ref text default null
) returns integer
language plpgsql security definer set search_path = public as $$
declare new_bal integer;
begin
  if p_amount <= 0 then raise exception 'amount must be positive'; end if;
  update public.profiles
     set credits = credits - p_amount
   where id = p_user and credits >= p_amount
   returning credits into new_bal;
  if new_bal is null then
    return -1;                 -- 잔액 부족(차감 안 됨)
  end if;
  insert into public.credit_ledger (user_id, delta, reason, ref)
       values (p_user, -p_amount, p_reason, p_ref);
  return new_bal;
end $$;

-- ── 6) refund_credits: Gemini 호출 실패 시 예약분 환불 ────────────────────────
create or replace function public.refund_credits(
  p_user uuid, p_amount int, p_ref text default null
) returns integer
language plpgsql security definer set search_path = public as $$
declare new_bal integer;
begin
  update public.profiles set credits = credits + p_amount
   where id = p_user returning credits into new_bal;
  insert into public.credit_ledger (user_id, delta, reason, ref)
       values (p_user, p_amount, 'refund', p_ref);
  return new_bal;
end $$;

-- ── 7) refill_if_due: 마지막 충전 후 1달 지났으면 grant까지 보충(누적 X) ────────
--    Worker가 spend 직전에 한 번 호출. 잔액은 grant 밑으로만 보충(초과분 유지).
create or replace function public.refill_if_due(p_user uuid)
returns integer
language plpgsql security definer set search_path = public as $$
declare new_bal integer;
begin
  update public.profiles
     set credits = greatest(credits, monthly_grant),
         last_refill_at = now()
   where id = p_user
     and now() >= last_refill_at + interval '1 month'
   returning credits into new_bal;
  if new_bal is null then
    select credits into new_bal from public.profiles where id = p_user;
  end if;
  return new_bal;
end $$;

-- ── 8) RPC 실행 권한: service_role(Worker)만. 클라이언트 직접 호출 차단 ─────────
revoke all on function public.spend_credits(uuid,int,text,text) from public, anon, authenticated;
revoke all on function public.refund_credits(uuid,int,text)     from public, anon, authenticated;
revoke all on function public.refill_if_due(uuid)               from public, anon, authenticated;
grant execute on function public.spend_credits(uuid,int,text,text) to service_role;
grant execute on function public.refund_credits(uuid,int,text)     to service_role;
grant execute on function public.refill_if_due(uuid)               to service_role;
