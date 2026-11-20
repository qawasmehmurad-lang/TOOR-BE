-- Require every merchant to accept the current 10% commission agreement before new sales.
create or replace function public.set_order_item_platform_commission()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' and not exists (
    select 1
    from public.merchant_program_acceptances ma
    where ma.store_id = new.store_id
      and ma.platform_terms_accepted = true
      and ma.terms_version = '1.2'
  ) then
    raise exception 'Merchant must accept the current TOOR BE platform terms before accepting sales';
  end if;

  new.commission_percent := 10.00;
  new.commission_jod := round(coalesce(new.line_total_jod, 0) * 0.10, 3);
  return new;
end;
$$;

revoke all on function public.set_order_item_platform_commission() from public, anon, authenticated;
