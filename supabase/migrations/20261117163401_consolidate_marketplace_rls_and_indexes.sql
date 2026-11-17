
create index if not exists product_reviews_user_idx on public.product_reviews(user_id);
create index if not exists ad_banners_created_by_idx on public.ad_banners(created_by);

drop policy if exists "addresses owner manage" on public.addresses;
drop policy if exists addresses_merchant_fulfillment_read on public.addresses;
create policy addresses_select_scoped on public.addresses for select to authenticated
using(user_id=(select auth.uid()) or (select private.is_admin()) or exists(select 1 from public.orders o where o.address_id=addresses.id and (select private.owns_order(o.id))));
create policy addresses_insert_owner on public.addresses for insert to authenticated
with check(user_id=(select auth.uid()) or (select private.is_admin()));
create policy addresses_update_owner on public.addresses for update to authenticated
using(user_id=(select auth.uid()) or (select private.is_admin()))
with check(user_id=(select auth.uid()) or (select private.is_admin()));
create policy addresses_delete_owner on public.addresses for delete to authenticated
using(user_id=(select auth.uid()) or (select private.is_admin()));

drop policy if exists "orders buyer or admin" on public.orders;
drop policy if exists orders_merchant_read on public.orders;
create policy orders_buyer_merchant_admin_read on public.orders for select to authenticated
using(buyer_id=(select auth.uid()) or (select private.owns_order(id)) or (select private.is_admin()));

drop policy if exists "shipments buyer courier admin read" on public.shipments;
drop policy if exists shipments_merchant_read on public.shipments;
drop policy if exists "shipments admin manage" on public.shipments;
create policy shipments_buyer_courier_merchant_admin_read on public.shipments for select to authenticated
using(exists(select 1 from public.orders o where o.id=shipments.order_id and o.buyer_id=(select auth.uid()))
 or courier_id=(select auth.uid()) or (select private.owns_order(order_id)) or (select private.is_admin()));
create policy shipments_admin_insert on public.shipments for insert to authenticated with check((select private.is_admin()));
create policy shipments_admin_update on public.shipments for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy shipments_admin_delete on public.shipments for delete to authenticated using((select private.is_admin()));

drop policy if exists "order event buyer courier admin read" on public.order_events;
drop policy if exists order_events_merchant_read on public.order_events;
create policy order_events_scoped_read on public.order_events for select to authenticated
using(exists(select 1 from public.orders o where o.id=order_events.order_id and o.buyer_id=(select auth.uid()))
 or (select private.is_assigned_courier(order_id)) or (select private.owns_order(order_id)) or (select private.is_admin()));

drop policy if exists coupons_admin_manage on public.coupons;
drop policy if exists coupons_public_active_read on public.coupons;
create policy coupons_scoped_read on public.coupons for select to anon,authenticated
using((is_active=true and starts_at<=now() and expires_at>now()) or (select private.is_admin()));
create policy coupons_admin_insert on public.coupons for insert to authenticated with check((select private.is_admin()));
create policy coupons_admin_update on public.coupons for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy coupons_admin_delete on public.coupons for delete to authenticated using((select private.is_admin()));

drop policy if exists coupon_products_admin_manage on public.coupon_products;
drop policy if exists coupon_products_read on public.coupon_products;
create policy coupon_products_scoped_read on public.coupon_products for select to anon,authenticated using(true);
create policy coupon_products_admin_insert on public.coupon_products for insert to authenticated with check((select private.is_admin()));
create policy coupon_products_admin_update on public.coupon_products for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy coupon_products_admin_delete on public.coupon_products for delete to authenticated using((select private.is_admin()));

drop policy if exists coupon_assignments_admin_manage on public.coupon_assignments;
drop policy if exists coupon_assignments_owner_read on public.coupon_assignments;
create policy coupon_assignments_scoped_read on public.coupon_assignments for select to authenticated using(user_id=(select auth.uid()) or (select private.is_admin()));
create policy coupon_assignments_admin_insert on public.coupon_assignments for insert to authenticated with check((select private.is_admin()));
create policy coupon_assignments_admin_update on public.coupon_assignments for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy coupon_assignments_admin_delete on public.coupon_assignments for delete to authenticated using((select private.is_admin()));

drop policy if exists loyalty_rewards_admin_manage on public.loyalty_rewards;
drop policy if exists loyalty_rewards_public_read on public.loyalty_rewards;
create policy loyalty_rewards_scoped_read on public.loyalty_rewards for select to anon,authenticated using(is_active=true or (select private.is_admin()));
create policy loyalty_rewards_admin_insert on public.loyalty_rewards for insert to authenticated with check((select private.is_admin()));
create policy loyalty_rewards_admin_update on public.loyalty_rewards for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy loyalty_rewards_admin_delete on public.loyalty_rewards for delete to authenticated using((select private.is_admin()));

drop policy if exists product_reviews_admin_manage on public.product_reviews;
drop policy if exists product_reviews_public_read on public.product_reviews;
drop policy if exists product_reviews_verified_insert on public.product_reviews;
create policy product_reviews_scoped_read on public.product_reviews for select to anon,authenticated using(is_approved=true or (select private.is_admin()));
create policy product_reviews_verified_or_admin_insert on public.product_reviews for insert to authenticated
with check((select private.is_admin()) or (user_id=(select auth.uid()) and is_approved=true and exists(
 select 1 from public.order_items oi join public.orders o on o.id=oi.order_id
 where oi.id=product_reviews.order_item_id and oi.product_id=product_reviews.product_id and o.buyer_id=(select auth.uid()) and o.status='delivered'
)));
create policy product_reviews_admin_update on public.product_reviews for update to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy product_reviews_admin_delete on public.product_reviews for delete to authenticated using((select private.is_admin()));
