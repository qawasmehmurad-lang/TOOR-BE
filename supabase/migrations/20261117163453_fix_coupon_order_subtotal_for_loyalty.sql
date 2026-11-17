create or replace function public.sync_order_subtotal_for_coupon()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 if new.coupon_id is not null then
  select coalesce(sum(oi.line_total_jod),0) into new.subtotal_jod
  from public.order_items oi where oi.order_id=new.id;
 end if;
 return new;
end; $$;
revoke execute on function public.sync_order_subtotal_for_coupon() from public,anon,authenticated;
drop trigger if exists sync_order_subtotal_before_coupon_update on public.orders;
create trigger sync_order_subtotal_before_coupon_update
before update of coupon_id,discount_jod on public.orders
for each row execute function public.sync_order_subtotal_for_coupon();