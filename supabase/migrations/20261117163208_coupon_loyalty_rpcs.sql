
create or replace function public.award_loyalty_points_on_delivery()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_points integer; v_tx_id uuid; v_eligible_total numeric(12,3);
begin
 if new.status='delivered' and old.status is distinct from 'delivered' then
  v_eligible_total:=greatest(0,new.subtotal_jod-coalesce(new.discount_jod,0));
  v_points:=case when v_eligible_total>=200 then 300 when v_eligible_total>=100 then 200 when v_eligible_total>=10 then 100 else 0 end;
  if v_points>0 then
   insert into public.loyalty_transactions(user_id,order_id,points_change,kind,description) values(new.buyer_id,new.id,v_points,'earn','نقاط مكتسبة بعد تسليم الطلب') on conflict do nothing returning id into v_tx_id;
   if v_tx_id is not null then
    insert into public.loyalty_accounts(user_id,balance,lifetime_earned,updated_at) values(new.buyer_id,v_points,v_points,now())
    on conflict(user_id) do update set balance=public.loyalty_accounts.balance+excluded.balance,lifetime_earned=public.loyalty_accounts.lifetime_earned+excluded.lifetime_earned,updated_at=now();
    insert into public.notifications(user_id,title,body,kind,data) values(new.buyer_id,'تمت إضافة نقاط إلى رصيدك','حصلت على '||v_points||' نقطة بعد تسليم طلبك','loyalty_points',jsonb_build_object('order_id',new.id,'points',v_points));
   end if;
  end if;
  update public.loyalty_redemptions set status='fulfilled',updated_at=now() where order_id=new.id and status in ('pending','accepted');
 end if;
 return new;
end; $$;
revoke execute on function public.award_loyalty_points_on_delivery() from public,anon,authenticated;
drop trigger if exists award_loyalty_points_after_delivery on public.orders;
create trigger award_loyalty_points_after_delivery after update of status on public.orders for each row execute function public.award_loyalty_points_on_delivery();

drop function if exists public.place_order(uuid,jsonb,text);
create or replace function public.place_order(p_address_id uuid,p_items jsonb,p_buyer_note text default null,p_coupon_code text default null)
returns table(order_id uuid,order_number text,subtotal_jod numeric,delivery_fee_jod numeric,total_jod numeric,delivery_otp text)
language plpgsql security definer set search_path=''
as $$
declare
 v_user uuid:=auth.uid(); v_address public.addresses%rowtype; v_order_id uuid; v_order_number text;
 v_subtotal numeric(12,3):=0; v_delivery_fee numeric(12,3):=2.000; v_discount numeric(12,3):=0; v_eligible numeric(12,3):=0;
 v_item jsonb; v_product public.products%rowtype; v_variant public.product_variants%rowtype; v_coupon public.coupons%rowtype;
 v_variant_id uuid; v_variant_label text; v_qty integer; v_used_count integer; v_user_used_count integer;
 v_otp text:=lpad(floor(random()*1000000)::int::text,6,'0');
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Cart is empty'; end if;
 select * into v_address from public.addresses where id=p_address_id and user_id=v_user;
 if not found then raise exception 'Delivery address not found'; end if;
 select coalesce((value->>'default_fee_jod')::numeric,2.000) into v_delivery_fee from public.platform_settings where key='delivery';
 v_delivery_fee:=coalesce(v_delivery_fee,2.000);
 if nullif(trim(p_coupon_code),'') is not null then
  select * into v_coupon from public.coupons where upper(code)=upper(trim(p_coupon_code)) and is_active and starts_at<=now() and expires_at>now() for update;
  if not found then raise exception 'كود الخصم غير صالح أو انتهت صلاحيته'; end if;
  select count(*) into v_used_count from public.coupon_redemptions where coupon_id=v_coupon.id;
  if v_coupon.usage_limit is not null and v_used_count>=v_coupon.usage_limit then raise exception 'تم استنفاد عدد استخدامات هذا الكوبون'; end if;
  select count(*) into v_user_used_count from public.coupon_redemptions where coupon_id=v_coupon.id and user_id=v_user;
  if v_user_used_count>=v_coupon.per_user_limit then raise exception 'وصلت إلى الحد المسموح لاستخدام هذا الكوبون'; end if;
  if exists(select 1 from public.coupon_assignments ca where ca.coupon_id=v_coupon.id) and not exists(select 1 from public.coupon_assignments ca where ca.coupon_id=v_coupon.id and ca.user_id=v_user) then raise exception 'هذا الكوبون مخصص لمستخدمين محددين'; end if;
 end if;
 insert into public.orders(buyer_id,address_id,status,payment_method,delivery_fee_jod,buyer_note,delivery_otp_hash)
 values(v_user,p_address_id,'placed','cash_on_delivery',v_delivery_fee,left(p_buyer_note,1000),encode(digest(v_otp,'sha256'),'hex')) returning id,order_number into v_order_id,v_order_number;
 for v_item in select value from jsonb_array_elements(p_items) loop
  if (v_item->>'quantity') is null or (v_item->>'quantity') !~ '^[1-9][0-9]{0,3}$' then raise exception 'Invalid item quantity'; end if;
  v_qty:=(v_item->>'quantity')::integer;
  select * into v_product from public.products where id=(v_item->>'product_id')::uuid for update;
  if not found or v_product.status<>'active' then raise exception 'Product is unavailable'; end if;
  if not private.is_active_store(v_product.store_id) then raise exception 'Store is unavailable'; end if;
  v_variant_id:=nullif(v_item->>'variant_id','')::uuid; v_variant_label:=null;
  if v_variant_id is not null then
   select * into v_variant from public.product_variants where id=v_variant_id and product_id=v_product.id for update;
   if not found then raise exception 'Selected product option is unavailable'; end if;
   if v_variant.stock_quantity<v_qty then raise exception 'Insufficient stock for selected product option'; end if;
   update public.product_variants set stock_quantity=stock_quantity-v_qty where id=v_variant.id;
   v_variant_label:=coalesce(nullif(concat_ws(' / ',nullif(v_variant.color,''),nullif(v_variant.size,'')),''),v_variant.option_value);
  elsif exists(select 1 from public.product_variants pv where pv.product_id=v_product.id and (pv.color is not null or pv.size is not null)) then raise exception 'Please select an available product option';
  end if;
  if v_product.stock_quantity<v_qty then raise exception 'Insufficient stock for %',v_product.name; end if;
  update public.products set stock_quantity=stock_quantity-v_qty,status=case when stock_quantity-v_qty=0 then 'out_of_stock'::public.product_status else status end where id=v_product.id;
  insert into public.order_items(order_id,store_id,product_id,product_name,unit_price_jod,quantity,line_total_jod,variant_id,variant_label)
  values(v_order_id,v_product.store_id,v_product.id,v_product.name,v_product.price_jod,v_qty,v_product.price_jod*v_qty,v_variant_id,v_variant_label);
  v_subtotal:=v_subtotal+(v_product.price_jod*v_qty);
 end loop;
 if nullif(trim(p_coupon_code),'') is not null then
  if v_coupon.scope='cart' then
   if v_subtotal<v_coupon.minimum_cart_jod then raise exception 'الحد الأدنى للشراء لاستخدام الكوبون هو % دينار',v_coupon.minimum_cart_jod; end if;
   v_eligible:=v_subtotal;
  else
   select coalesce(sum(oi.line_total_jod),0) into v_eligible from public.order_items oi join public.coupon_products cp on cp.product_id=oi.product_id and cp.coupon_id=v_coupon.id where oi.order_id=v_order_id;
   if v_eligible<=0 then raise exception 'لا يحتوي الطلب على منتجات مشمولة بهذا الكوبون'; end if;
   if exists(select 1 from public.order_items oi join public.coupon_products cp on cp.product_id=oi.product_id and cp.coupon_id=v_coupon.id join public.stores st on st.id=oi.store_id left join public.merchant_program_acceptances ma on ma.store_id=st.id where oi.order_id=v_order_id and coalesce(ma.coupons_accepted,false)=false) then raise exception 'أحد المتاجر لم يوافق بعد على شروط حملات الخصم'; end if;
  end if;
  if v_coupon.discount_type='percent' then v_discount:=round(v_eligible*v_coupon.discount_value/100,3); else v_discount:=least(v_coupon.discount_value,v_eligible); end if;
  if v_coupon.max_discount_jod is not null then v_discount:=least(v_discount,v_coupon.max_discount_jod); end if;
  v_discount:=least(v_discount,v_subtotal);
  if v_discount<=0 then raise exception 'قيمة الخصم غير صالحة لهذا الطلب'; end if;
  update public.orders set coupon_id=v_coupon.id,discount_jod=v_discount,total_jod=v_subtotal+v_delivery_fee-v_discount where id=v_order_id;
  insert into public.coupon_redemptions(coupon_id,user_id,order_id,discount_jod) values(v_coupon.id,v_user,v_order_id,v_discount);
  insert into public.notifications(user_id,title,body,kind,data) values(v_user,'تم تطبيق كوبون الخصم','تم خصم '||v_discount||' دينار من طلبك','coupon_used',jsonb_build_object('coupon_id',v_coupon.id,'order_id',v_order_id));
 else update public.orders set subtotal_jod=v_subtotal,total_jod=v_subtotal+v_delivery_fee where id=v_order_id;
 end if;
 insert into public.shipments(order_id,status) values(v_order_id,'awaiting_assignment');
 insert into public.order_events(order_id,actor_id,event_type,description) values(v_order_id,v_user,'order_placed','تم استلام الطلب بنجاح');
 return query select v_order_id,v_order_number,v_subtotal,v_delivery_fee,v_subtotal+v_delivery_fee-v_discount,v_otp;
end; $$;
revoke execute on function public.place_order(uuid,jsonb,text,text) from public,anon;
grant execute on function public.place_order(uuid,jsonb,text,text) to authenticated;

create or replace function public.preview_coupon(p_code text,p_items jsonb)
returns numeric language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_coupon public.coupons%rowtype; v_subtotal numeric(12,3):=0; v_eligible numeric(12,3):=0; v_discount numeric(12,3):=0; v_item jsonb; v_product public.products%rowtype; v_qty integer;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Cart is empty'; end if;
 select * into v_coupon from public.coupons where upper(code)=upper(trim(p_code)) and is_active and starts_at<=now() and expires_at>now();
 if not found then raise exception 'كود الخصم غير صالح أو انتهت صلاحيته'; end if;
 if exists(select 1 from public.coupon_assignments ca where ca.coupon_id=v_coupon.id) and not exists(select 1 from public.coupon_assignments ca where ca.coupon_id=v_coupon.id and ca.user_id=v_user) then raise exception 'هذا الكوبون مخصص لمستخدمين محددين'; end if;
 if (select count(*) from public.coupon_redemptions where coupon_id=v_coupon.id)>=coalesce(v_coupon.usage_limit,2147483647) then raise exception 'تم استنفاد عدد استخدامات هذا الكوبون'; end if;
 if (select count(*) from public.coupon_redemptions where coupon_id=v_coupon.id and user_id=v_user)>=v_coupon.per_user_limit then raise exception 'وصلت إلى الحد المسموح لاستخدام هذا الكوبون'; end if;
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_qty:=greatest(1,least(1000,coalesce((v_item->>'quantity')::integer,1)));
  select * into v_product from public.products where id=(v_item->>'product_id')::uuid and status='active';
  if not found then raise exception 'Product is unavailable'; end if;
  v_subtotal:=v_subtotal+(v_product.price_jod*v_qty);
  if v_coupon.scope='cart' or exists(select 1 from public.coupon_products cp where cp.coupon_id=v_coupon.id and cp.product_id=v_product.id) then
   v_eligible:=v_eligible+(v_product.price_jod*v_qty);
   if v_coupon.scope='products' and not exists(select 1 from public.merchant_program_acceptances ma where ma.store_id=v_product.store_id and ma.coupons_accepted=true) then raise exception 'المتجر لم يوافق بعد على شروط حملات الخصم'; end if;
  end if;
 end loop;
 if v_coupon.scope='cart' and v_subtotal<v_coupon.minimum_cart_jod then raise exception 'الحد الأدنى للشراء هو % دينار',v_coupon.minimum_cart_jod; end if;
 if v_eligible<=0 then raise exception 'لا توجد منتجات مؤهلة لهذا الكوبون'; end if;
 if v_coupon.discount_type='percent' then v_discount:=round(v_eligible*v_coupon.discount_value/100,3); else v_discount:=least(v_coupon.discount_value,v_eligible); end if;
 if v_coupon.max_discount_jod is not null then v_discount:=least(v_discount,v_coupon.max_discount_jod); end if;
 return least(v_discount,v_subtotal);
end; $$;
revoke execute on function public.preview_coupon(text,jsonb) from public,anon;
grant execute on function public.preview_coupon(text,jsonb) to authenticated;

create or replace function public.redeem_loyalty_reward(p_reward_id uuid,p_address_id uuid)
returns table(order_number text,delivery_otp text,points_spent integer,total_jod numeric)
language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_reward public.loyalty_rewards%rowtype; v_product public.products%rowtype; v_address public.addresses%rowtype; v_balance integer; v_fee numeric(12,3):=2.000; v_order_id uuid; v_order_number text; v_otp text:=lpad(floor(random()*1000000)::int::text,6,'0');
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 select * into v_address from public.addresses where id=p_address_id and user_id=v_user;
 if not found then raise exception 'Delivery address not found'; end if;
 select * into v_reward from public.loyalty_rewards where id=p_reward_id and is_active=true for update;
 if not found or v_reward.points_cost<>1000 or v_reward.reward_value_jod<>5.000 then raise exception 'Reward is unavailable'; end if;
 if not exists(select 1 from public.merchant_program_acceptances ma where ma.store_id=v_reward.store_id and ma.loyalty_accepted=true) then raise exception 'المتجر لم يوافق بعد على شروط برنامج النقاط'; end if;
 select * into v_product from public.products where id=v_reward.product_id and store_id=v_reward.store_id and status='active' for update;
 if not found or v_product.price_jod<>5.000 or v_product.stock_quantity<1 then raise exception 'Reward product is unavailable'; end if;
 select balance into v_balance from public.loyalty_accounts where user_id=v_user for update;
 if coalesce(v_balance,0)<v_reward.points_cost then raise exception 'رصيد نقاطك غير كافٍ'; end if;
 select coalesce((value->>'default_fee_jod')::numeric,2.000) into v_fee from public.platform_settings where key='delivery'; v_fee:=coalesce(v_fee,2.000);
 update public.products set stock_quantity=stock_quantity-1,status=case when stock_quantity-1=0 then 'out_of_stock'::public.product_status else status end where id=v_product.id;
 insert into public.orders(buyer_id,address_id,status,payment_method,subtotal_jod,delivery_fee_jod,discount_jod,total_jod,buyer_note,delivery_otp_hash)
 values(v_user,p_address_id,'placed','cash_on_delivery',5.000,v_fee,5.000,v_fee,'استبدال نقاط مكافآت',encode(digest(v_otp,'sha256'),'hex')) returning id,order_number into v_order_id,v_order_number;
 insert into public.order_items(order_id,store_id,product_id,product_name,product_image_url,unit_price_jod,quantity,line_total_jod,merchant_status)
 select v_order_id,v_product.store_id,v_product.id,v_product.name,(select pi.image_url from public.product_images pi where pi.product_id=v_product.id order by pi.sort_order limit 1),5.000,1,5.000,'new';
 insert into public.shipments(order_id,status) values(v_order_id,'awaiting_assignment');
 insert into public.order_events(order_id,actor_id,event_type,description) values(v_order_id,v_user,'loyalty_reward_order','طلب استبدال نقاط مقابل منتج بقيمة 5 دنانير');
 update public.loyalty_accounts set balance=balance-v_reward.points_cost,updated_at=now() where user_id=v_user;
 insert into public.loyalty_transactions(user_id,order_id,points_change,kind,description) values(v_user,v_order_id,-v_reward.points_cost,'redeem','استبدال 1000 نقطة بمنتج بقيمة 5 دنانير');
 insert into public.loyalty_redemptions(user_id,reward_id,points_spent,status,order_id) values(v_user,v_reward.id,v_reward.points_cost,'pending',v_order_id);
 insert into public.notifications(user_id,title,body,kind,data) values(v_user,'تم تأكيد استبدال النقاط','تم حجز المنتج مقابل 1000 نقطة. رسوم التوصيل عند الاستلام: '||v_fee||' دينار','loyalty_redemption',jsonb_build_object('order_id',v_order_id));
 insert into public.notifications(user_id,title,body,kind,data) select s.owner_id,'طلب استبدال نقاط لمنتج متجرك','تم إنشاء طلب استبدال لنفس المنتج بقيمة 5 دنانير. يرجى تجهيز المنتج.','loyalty_reward_order',jsonb_build_object('order_id',v_order_id,'product_id',v_product.id) from public.stores s where s.id=v_product.store_id;
 return query select v_order_number,v_otp,v_reward.points_cost,v_fee;
end; $$;
revoke execute on function public.redeem_loyalty_reward(uuid,uuid) from public,anon;
grant execute on function public.redeem_loyalty_reward(uuid,uuid) to authenticated;
