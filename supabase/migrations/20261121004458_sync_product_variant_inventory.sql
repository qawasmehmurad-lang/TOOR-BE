create or replace function public.sync_product_stock_from_variants()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_product_id uuid;
  old_product_id uuid;
begin
  if tg_op = 'DELETE' then
    target_product_id := old.product_id;
  else
    target_product_id := new.product_id;
    if tg_op = 'UPDATE' and old.product_id is distinct from new.product_id then
      old_product_id := old.product_id;
    end if;
  end if;
  update public.products p
  set stock_quantity = totals.total_stock,
      status = case
        when totals.total_stock = 0 then 'out_of_stock'::public.product_status
        when p.status = 'out_of_stock' then 'active'::public.product_status
        else p.status
      end,
      updated_at = now()
  from (select coalesce(sum(v.stock_quantity), 0)::integer as total_stock from public.product_variants v where v.product_id = target_product_id) totals
  where p.id = target_product_id;
  if old_product_id is not null then
    update public.products p
    set stock_quantity = totals.total_stock,
        status = case
          when totals.total_stock = 0 then 'out_of_stock'::public.product_status
          when p.status = 'out_of_stock' then 'active'::public.product_status
          else p.status
        end,
        updated_at = now()
    from (select coalesce(sum(v.stock_quantity), 0)::integer as total_stock from public.product_variants v where v.product_id = old_product_id) totals
    where p.id = old_product_id;
  end if;
  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;
revoke all on function public.sync_product_stock_from_variants() from public, anon, authenticated;
drop trigger if exists trg_sync_product_stock_from_variants on public.product_variants;
create trigger trg_sync_product_stock_from_variants
after insert or update of stock_quantity, product_id or delete
on public.product_variants
for each row execute function public.sync_product_stock_from_variants();
