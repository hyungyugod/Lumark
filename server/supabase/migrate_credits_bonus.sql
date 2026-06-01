-- 크레딧 최종 정책: 가입 보너스 200 + 매월 충전 100.
-- (넉넉한 첫인상 + 지속가능한 월 한도. 월 비용이 누적 비용의 동력이라 월을 낮춤.)
-- 이전 크레딧 마이그레이션 실행 여부와 무관하게 이 파일 하나로 최종값에 맞춰짐.
-- Supabase SQL Editor에 붙여넣고 Run.

-- 신규 기본값: 가입 보너스 200, 월 충전 목표 100.
alter table public.profiles alter column credits      set default 200;
alter table public.profiles alter column monthly_grant set default 100;

-- 기존 사용자 월 충전 기준을 100으로 보정(기존 잔액은 건드리지 않음).
update public.profiles set monthly_grant = 100 where monthly_grant <> 100;

-- 가입 트리거: 신규 보너스 200.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, credits) values (new.id, 200);
  insert into public.credit_ledger (user_id, delta, reason)
       values (new.id, 200, 'signup');
  return new;
end $$;
