-- Verified product reviews and public delivered-sales metrics for trends.
create table if not exists public.product_reviews(id uuid primary key default gen_random_uuid(),product_id uuid not null references public.products(id) on delete cascade,user_id uuid not null references public.profiles(id) on delete cascade,order_item_id uuid not null unique references public.order_items(id) on delete cascade,rating smallint not null check(rating between 1 and 5),review_text text,is_approved boolean not null default true,created_at timestamptz not null default now());
create index if not exists product_reviews_product_idx on public.product_reviews(product_id,is_approved,created_at desc);
alter table public.product_reviews enable row level security;
grant select on public.product_reviews to anon,authenticated;
grant insert on public.product_reviews to authenticated;
grant all on public.product_reviews to service_role;
drop policy if exists product_reviews_public_read on public.product_reviews;
create policy product_reviews_public_read on public.product_reviews for select to anon,authenticated using(is_approved=true or (select private.is_admin()));
drop policy if exists product_reviews_verified_insert on public.product_reviews;
create policy product_reviews_verified_insert on public.product_reviews for insert to authenticated with check(user_id=(select auth.uid()) and is_approved=true and exists(select 1 from public.order_items oi join public.orders o on o.id=oi.order_id where oi.id=product_reviews.order_item_id and oi.product_id=product_reviews.product_id and o.buyer_id=(select auth.uid()) and o.status='delivered'));
drop policy if exists product_reviews_admin_manage on public.product_reviews;
create policy product_reviews_admin_manage on public.product_reviews for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create table if not exists public.product_sales_metrics(product_id uuid primary key references public.products(id) on delete cascade,delivered_units bigint not null default 0,delivered_orders bigint not null default 0,updated_at timestamptz not null default now());
alter table public.product_sales_metrics enable row level security;
grant select on public.product_sales_metrics to anon,authenticated;
grant all on public.product_sales_metrics to service_role;
drop policy if exists product_sales_metrics_public_read on public.product_sales_metrics;
create policy product_sales_metrics_public_read on public.product_sales_metrics for select to anon,authenticated using(true);
create or replace function public.update_product_sales_metrics_after_delivery()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_item record;
begin
 if new.status='delivered' and old.status is distinct from 'delivered' then
  for v_item in select oi.product_id,oi.quantity from public.order_items oi where oi.order_id=new.id and oi.product_id is not null loop
   insert into public.product_sales_metrics(product_id,delivered_units,delivered_orders,updated_at) values(v_item.product_id,v_item.quantity,1,now())
   on conflict(product_id) do update set delivered_units=public.product_sales_metrics.delivered_units+excluded.delivered_units,delivered_orders=public.product_sales_metrics.delivered_orders+1,updated_at=now();
  end loop;
 end if; return new;
end; $$;
revoke execute on function public.update_product_sales_metrics_after_delivery() from public,anon,authenticated;
drop trigger if exists update_product_sales_metrics_after_delivery on public.orders;
create trigger update_product_sales_metrics_after_delivery after update of status on public.orders for each row execute function public.update_product_sales_metrics_after_delivery();
insert into public.product_sales_metrics(product_id,delivered_units,delivered_orders,updated_at) select oi.product_id,sum(oi.quantity)::bigint,count(distinct o.id)::bigint,now() from public.order_items oi join public.orders o on o.id=oi.order_id where o.status='delivered' and oi.product_id is not null group by oi.product_id on conflict(product_id) do nothing;
