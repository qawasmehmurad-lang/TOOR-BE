create or replace function public.notify_order_event_participants()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_buyer_id uuid;
  v_order_number text;
  v_event_label text;
  v_shipment public.shipments%rowtype;
  v_item record;
  v_title text;
  v_body text;
begin
  select o.buyer_id, o.order_number
    into v_buyer_id, v_order_number
  from public.orders o
  where o.id = new.order_id;

  if v_buyer_id is null then
    return new;
  end if;

  v_event_label := case
    when new.event_type = 'order_placed' then 'تم استلام طلبك'
    when new.event_type = 'merchant_item_accepted' then 'وافق التاجر على طلبك'
    when new.event_type = 'merchant_item_rejected' then 'تعذر توفير أحد منتجات طلبك'
    when new.event_type = 'merchant_item_preparing' then 'بدأ تجهيز أحد منتجات طلبك'
    when new.event_type = 'merchant_item_ready_for_pickup' then 'أصبح أحد منتجات طلبك جاهزاً للاستلام'
    when new.event_type = 'shipment_assigned' then 'تم إسناد طلبك إلى مندوب'
    when new.event_type = 'shipment_collecting' then 'بدأ المندوب استلام طلبك'
    when new.event_type = 'shipment_at_hub' then 'وصل طلبك إلى مركز التجميع'
    when new.event_type = 'shipment_out_for_delivery' then 'طلبك خرج للتوصيل'
    when new.event_type = 'shipment_delivered' then 'تم تسليم طلبك بنجاح'
    else coalesce(new.description, 'تحديث جديد على طلبك')
  end;

  v_title := v_event_label;
  v_body := 'طلب رقم ' || v_order_number || ' · ' || coalesce(new.description, v_event_label);

  -- Buyer receives a private notification with a direct order-tracking destination.
  insert into public.notifications(user_id,title,body,kind,data)
  values (v_buyer_id,v_title,v_body,'order_stage',
    jsonb_build_object('route','buyer_orders','order_id',new.order_id,'event_id',new.id));

  -- Each merchant receives only their own product/order-item progress.
  for v_item in
    select oi.id, oi.store_id, oi.product_id, oi.product_name, st.owner_id
    from public.order_items oi
    join public.stores st on st.id = oi.store_id
    where oi.order_id = new.order_id
      and (new.metadata->>'store_id' is null or oi.store_id = (new.metadata->>'store_id')::uuid)
      and (new.metadata->>'order_item_id' is null or oi.id = (new.metadata->>'order_item_id')::uuid)
  loop
    if v_item.owner_id is not null then
      insert into public.notifications(user_id,title,body,kind,data)
      values (
        v_item.owner_id,
        case when new.event_type = 'order_placed' then 'طلب جديد يحتوي على منتج من متجرك' else 'تحديث على منتج ضمن طلب' end,
        v_item.product_name || ' · طلب ' || v_order_number || ' · ' || coalesce(new.description,v_event_label),
        'merchant_order_stage',
        jsonb_build_object('route','merchant_order','order_id',new.order_id,'order_item_id',v_item.id,'product_id',v_item.product_id,'product_name',v_item.product_name,'event_id',new.id)
      );
    end if;
  end loop;

  -- Assigned courier gets each subsequent delivery-stage update.
  select * into v_shipment
  from public.shipments sh
  where sh.order_id = new.order_id
  order by sh.created_at desc
  limit 1;

  if v_shipment.courier_id is not null then
    insert into public.notifications(user_id,title,body,kind,data)
    values (
      v_shipment.courier_id,
      'تحديث على شحنة مسندة إليك',
      'طلب ' || v_order_number || ' · ' || coalesce(new.description,v_event_label),
      'courier_order_stage',
      jsonb_build_object('route','courier_order','order_id',new.order_id,'shipment_id',v_shipment.id,'event_id',new.id)
    );
  end if;

  return new;
end;
$function$;

drop trigger if exists notify_order_event_participants on public.order_events;
create trigger notify_order_event_participants
after insert on public.order_events
for each row execute function public.notify_order_event_participants();

create or replace function public.notify_courier_assignment()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_buyer_id uuid;
  v_order_number text;
begin
  if new.courier_id is null or new.courier_id is not distinct from old.courier_id then
    return new;
  end if;

  select o.buyer_id,o.order_number into v_buyer_id,v_order_number
  from public.orders o where o.id=new.order_id;

  insert into public.notifications(user_id,title,body,kind,data)
  values (
    new.courier_id,
    'شحنة جديدة مسندة إليك',
    'تم إسناد الطلب ' || coalesce(v_order_number,'') || ' إليك. افتح الشحنات الحالية لمتابعة مراحل التوصيل.',
    'courier_order_assigned',
    jsonb_build_object('route','courier_order','order_id',new.order_id,'shipment_id',new.id)
  );

  if v_buyer_id is not null then
    insert into public.notifications(user_id,title,body,kind,data)
    values (
      v_buyer_id,
      'تم تعيين مندوب لطلبك',
      'تم إسناد طلب ' || v_order_number || ' إلى مندوب توصيل.',
      'order_stage',
      jsonb_build_object('route','buyer_orders','order_id',new.order_id,'shipment_id',new.id)
    );
  end if;

  return new;
end;
$function$;

drop trigger if exists notify_courier_assignment on public.shipments;
create trigger notify_courier_assignment
after update of courier_id on public.shipments
for each row execute function public.notify_courier_assignment();

revoke all on function public.notify_order_event_participants() from public, anon, authenticated;
revoke all on function public.notify_courier_assignment() from public, anon, authenticated;
