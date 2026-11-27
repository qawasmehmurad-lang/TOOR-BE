create table if not exists private.product_highlight_notification_log (
  product_id uuid not null references public.products(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  notification_kind text not null check (notification_kind in ('top_selling','top_rated')),
  sent_on date not null default current_date,
  primary key(product_id,user_id,notification_kind,sent_on)
);
revoke all on table private.product_highlight_notification_log from public,anon,authenticated;

create or replace function public.notify_product_highlights_after_delivery()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_product record;
  v_user record;
  v_image text;
  v_inserted boolean;
begin
  if new.status::text <> 'delivered' or old.status::text = 'delivered' then
    return new;
  end if;

  for v_product in
    with sales as (
      select oi.product_id,sum(oi.quantity)::bigint as sold_count
      from public.order_items oi
      join public.orders o on o.id=oi.order_id
      where o.status::text='delivered' and oi.product_id is not null
      group by oi.product_id
    ), rated as (
      select pr.product_id,avg(pr.rating)::numeric(4,2) as average_rating,count(*)::integer as review_count
      from public.product_reviews pr
      where pr.is_approved=true
      group by pr.product_id
      having count(*)>=3
    )
    select p.id,p.name,p.store_id,st.owner_id,'top_selling'::text as notification_kind,
      coalesce(s.sold_count,0)::bigint as metric_value,
      ('حقق المنتج '||p.name||' مبيعات مرتفعة على TOOR BE ('||coalesce(s.sold_count,0)||' قطعة مباعة).')::text as message
    from public.products p join public.stores st on st.id=p.store_id
    left join sales s on s.product_id=p.id
    where p.status::text='active' and coalesce(s.sold_count,0)>0
    order by coalesce(s.sold_count,0) desc,p.name
    limit 3
    union all
    select p.id,p.name,p.store_id,st.owner_id,'top_rated'::text,
      r.average_rating::bigint,
      ('حصل المنتج '||p.name||' على تقييم مرتفع ('||r.average_rating||'/5 من '||r.review_count||' تقييمات).')::text
    from public.products p join public.stores st on st.id=p.store_id
    join rated r on r.product_id=p.id
    where p.status::text='active'
    order by r.average_rating desc,r.review_count desc,p.name
    limit 3
  loop
    select pi.image_url into v_image from public.product_images pi
    where pi.product_id=v_product.id order by pi.sort_order,pi.id limit 1;

    for v_user in
      select pr.id from public.profiles pr
      where pr.role='buyer' and pr.is_blocked=false
    loop
      insert into private.product_highlight_notification_log(product_id,user_id,notification_kind,sent_on)
      values(v_product.id,v_user.id,v_product.notification_kind,current_date)
      on conflict do nothing;
      get diagnostics v_inserted = row_count;
      if v_inserted then
        insert into public.notifications(user_id,title,body,kind,data)
        values(v_user.id,
          case when v_product.notification_kind='top_selling' then 'منتج من الأكثر مبيعاً' else 'منتج من الأعلى تقييماً' end,
          v_product.message,
          'product_highlight',
          jsonb_build_object('route','product','product_id',v_product.id,'product_name',v_product.name,'image_url',v_image,'highlight_type',v_product.notification_kind)
        );
      end if;
    end loop;

    if v_product.owner_id is not null then
      insert into private.product_highlight_notification_log(product_id,user_id,notification_kind,sent_on)
      values(v_product.id,v_product.owner_id,v_product.notification_kind,current_date)
      on conflict do nothing;
      get diagnostics v_inserted = row_count;
      if v_inserted then
        insert into public.notifications(user_id,title,body,kind,data)
        values(v_product.owner_id,
          case when v_product.notification_kind='top_selling' then 'أداء مميز: منتجك من الأكثر مبيعاً' else 'أداء مميز: منتجك من الأعلى تقييماً' end,
          v_product.message,
          'merchant_product_highlight',
          jsonb_build_object('route','merchant_product','product_id',v_product.id,'product_name',v_product.name,'image_url',v_image,'highlight_type',v_product.notification_kind)
        );
      end if;
    end if;
  end loop;
  return new;
end;
$function$;

drop trigger if exists notify_product_highlights_after_delivery on public.orders;
create trigger notify_product_highlights_after_delivery
after update of status on public.orders
for each row when (new.status::text='delivered' and old.status::text is distinct from 'delivered')
execute function public.notify_product_highlights_after_delivery();
revoke all on function public.notify_product_highlights_after_delivery() from public,anon,authenticated;