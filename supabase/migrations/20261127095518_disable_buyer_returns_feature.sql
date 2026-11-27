-- Disable buyer-submitted return requests while preserving historical records.
drop policy if exists "returns buyer create" on public.returns;
revoke insert on table public.returns from anon, authenticated;
