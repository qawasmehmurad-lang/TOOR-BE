-- Admin-only settlement payout confirmation. Direct table updates remain revoked from clients.
create or replace function public.mark_store_settlement_paid(p_settlement_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Administrator access required';
  end if;

  select status into v_status
  from public.settlements
  where id = p_settlement_id
  for update;

  if not found then
    raise exception 'Settlement not found';
  end if;

  if v_status <> 'pending' then
    raise exception 'Only pending settlements can be marked as paid';
  end if;

  update public.settlements
  set status = 'paid', paid_at = now()
  where id = p_settlement_id;

  return true;
end;
$$;

revoke all on function public.mark_store_settlement_paid(uuid) from public, anon;
grant execute on function public.mark_store_settlement_paid(uuid) to authenticated;
