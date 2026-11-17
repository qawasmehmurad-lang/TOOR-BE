-- Merchant can read order details and update only the fulfillment state of their order items.
create or replace function private.owns_order(p_order_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.order_items oi join public.stores s on s.id=oi.store_id where oi.order_id=p_order_id and s.owner_id=(select auth.uid())); $$;
revoke execute on function private.owns_order(uuid) from public,anon;
grant execute on function private.owns_order(uuid) to authenticated;
drop policy if exists orders_merchant_read on public.orders;
create policy orders_merchant_read on public.orders for select to authenticated using((select private.owns_order(id)) or (select private.is_admin()));
drop policy if exists shipments_merchant_read on public.shipments;
create policy shipments_merchant_read on public.shipments for select to authenticated using((select private.owns_order(order_id)) or (select private.is_admin()));
drop policy if exists order_events_merchant_read on public.order_events;
create policy order_events_merchant_read on public.order_events for select to authenticated using((select private.owns_order(order_id)) or (select private.is_admin()));
drop policy if exists addresses_merchant_fulfillment_read on public.addresses;
create policy addresses_merchant_fulfillment_read on public.addresses for select to authenticated using(exists(select 1 from public.orders o where o.address_id=addresses.id and (select private.owns_order(o.id))));
create or replace function public.guard_and_log_merchant_order_item_status()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 if new.merchant_status is not distinct from old.merchant_status then return new; end if;
 if not (select private.is_admin()) then
  if not (select private.owns_store(old.store_id)) then raise exception 'Merchant access required'; end if;
  if new.id is distinct from old.id or new.order_id is distinct from old.order_id or new.store_id is distinct from old.store_id
   or new.product_id is distinct from old.product_id or new.product_name is distinct from old.product_name
   or new.product_image_url is distinct from old.product_image_url or new.variant_label is distinct from old.variant_label
   or new.unit_price_jod is distinct from old.unit_price_jod or new.quantity is distinct from old.quantity
   or new.line_total_jod is distinct from old.line_total_jod or new.variant_id is distinct from old.variant_id then
   raise exception 'Merchants may only update fulfillment status';
  end if;
 end if;
 if not ((old.merchant_status='new' and new.merchant_status in ('accepted','rejected')) or (old.merchant_status='accepted' and new.merchant_status='preparing') or (old.merchant_status='preparing' and new.merchant_status='ready_for_pickup')) then raise exception 'Invalid merchant fulfillment status transition'; end if;
 if new.merchant_status='accepted' then update public.orders set status='confirmed' where id=new.order_id and status='placed'; end if;
 insert into public.order_events(order_id,actor_id,event_type,description,metadata) values(new.order_id,auth.uid(),'merchant_item_'||new.merchant_status,case new.merchant_status when 'accepted' then 'وافق التاجر على تجهيز المنتج' when 'rejected' then 'تعذر على التاجر توفير المنتج' when 'preparing' then 'بدأ التاجر تجهيز المنتج' when 'ready_for_pickup' then 'أصبح المنتج جاهزاً للاستلام من التاجر' else 'تم تحديث حالة المنتج' end,jsonb_build_object('order_item_id',new.id,'store_id',new.store_id));
 return new;
end; $$;
revoke execute on function public.guard_and_log_merchant_order_item_status() from public,anon,authenticated;
drop trigger if exists merchant_order_item_status_guard on public.order_items;
create trigger merchant_order_item_status_guard before update of merchant_status on public.order_items for each row execute function public.guard_and_log_merchant_order_item_status();
create or replace function public.sync_loyalty_redemption_merchant_acceptance()
returns trigger language plpgsql security definer set search_path=''
as $$ begin if new.merchant_status='accepted' and old.merchant_status is distinct from 'accepted' then update public.loyalty_redemptions set status='accepted',updated_at=now() where order_id=new.order_id and status='pending'; end if; return new; end; $$;
revoke execute on function public.sync_loyalty_redemption_merchant_acceptance() from public,anon,authenticated;
drop trigger if exists sync_loyalty_redemption_after_merchant_acceptance on public.order_items;
create trigger sync_loyalty_redemption_after_merchant_acceptance after update of merchant_status on public.order_items for each row execute function public.sync_loyalty_redemption_merchant_acceptance();
