-- 본인 계정 self-service 삭제. Supabase SQL Editor에 붙여넣고 Run.
--
-- auth.users 행을 지우면 profiles / credit_ledger 가 ON DELETE CASCADE 로 함께 삭제됨
-- (schema.sql에서 references auth.users(id) on delete cascade 로 정의).
-- SECURITY DEFINER 라 postgres 권한으로 auth.users 삭제 가능. auth.uid()로 본인만.

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from auth.users where id = auth.uid();
end $$;

-- 로그인한 사용자만 호출 가능(본인 것만 지워짐). anon 차단.
revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;
