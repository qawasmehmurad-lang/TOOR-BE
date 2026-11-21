create or replace function public.merchant_add_inventory(p_product_id uuid,p_quantity integer,p_variant_id uuid default null)
returns integer language plpgsql security invoker set search_path = public, pg_temp as $$
declare resulting_stock integer;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_quantity is null or p_quantity < 1 or p_quantity > 100000 then raise exception 'Quantity must be between 1 and 100000'; end if;
 if p_variant_id is not null then
  update public.product_variants v set stock_quantity=v.stock_quantity+p_quantity
  from public.products p join public.stores s on s.id=p.store_id
  where v.id=p_variant_id and v.product_id=p_product_id and p.id=v.product_id and s.owner_id=auth.uid()
  returning v.stock_quantity into resulting_stock;
 else
  update public.products p set stock_quantity=p.stock_quantity+p_quantity,
   status=case when p.status='out_of_stock' then 'active'::public.product_status else p.status end, updated_at=now()
  from public.stores s
  where p.id=p_product_id and p.store_id=s.id and s.owner_id=auth.uid()
   and not exists(select 1 from public.product_variants v where v.product_id=p.id)
  returning p.stock_quantity into resulting_stock;
 end if;
 if resulting_stock is null then raise exception 'Product or variant not found, or not owned by this merchant'; end if;
 return resulting_stock;
end; $$;
revoke all on function public.merchant_add_inventory(uuid,integer,uuid) from public, anon;
grant execute on function public.merchant_add_inventory(uuid,integer,uuid) to authenticated;