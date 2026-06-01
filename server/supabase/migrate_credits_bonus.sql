-- 가입 보너스 200 → 100 (월 충전은 200 유지). 다계정 농사 억제.
-- migrate_credits_200.sql 실행 여부와 무관하게 최종값으로 맞춤. SQL Editor에 붙여넣고 Run.

-- 가입 보너스(신규 profiles 기본값) = 100, 월 충전 목표 = 200.
alter table public.profiles alter column credits      set default 100;
alter table public.profiles alter column monthly_grant set default 200;

-- 기존 사용자 월 충전 기준은 200 유지(혹시 안 맞으면 보정). 기존 잔액은 건드리지 않음.
update public.profiles set monthly_grant = 200 where monthly_grant <> 200;

-- 가입 트리거: 신규 보너스 100.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, credits) values (new.id, 100);
  insert into public.credit_ledger (user_id, delta, reason)
       values (new.id, 100, 'signup');
  return new;
end $$;
