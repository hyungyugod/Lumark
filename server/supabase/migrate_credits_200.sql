-- 크레딧 기본값 100 → 200 (가입 보너스 + 월 충전).
-- 이미 schema.sql을 실행한 DB에 적용. Supabase SQL Editor에 붙여넣고 Run.

-- 신규 가입/충전 기본값.
alter table public.profiles alter column credits      set default 200;
alter table public.profiles alter column monthly_grant set default 200;

-- 기존 사용자(있다면) 월 충전 기준을 200으로. (다음 충전 때 200까지 채워짐)
update public.profiles set monthly_grant = 200 where monthly_grant < 200;

-- 가입 트리거: 신규 보너스 100 → 200.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, credits) values (new.id, 200);
  insert into public.credit_ledger (user_id, delta, reason)
       values (new.id, 200, 'signup');
  return new;
end $$;
