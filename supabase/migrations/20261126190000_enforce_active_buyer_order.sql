create or replace function private.enforce_active_buyer_order()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.buyer_id is null or not exists (
    select 1
    from public.profiles p
    where p.id = new.buyer_id
      and p.is_blocked = false
  ) then
    raise exception 'An active buyer account is required to create an order';
  end if;

  if auth.uid() is not null and new.buyer_id is distinct from auth.uid() then
    raise exception 'Orders can only be created for the signed-in buyer';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_active_buyer_order on public.orders;

create trigger enforce_active_buyer_order
before insert on public.orders
for each row
execute function private.enforce_active_buyer_order();
