create or replace function public.approve_merchant_application(p_application_id uuid, p_store_slug text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_app public.merchant_applications%rowtype; v_store_id uuid;
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Administrator access required';
  end if;
  select * into v_app
  from public.merchant_applications
  where id = p_application_id and status = 'pending'
  for update;
  if not found then raise exception 'Pending merchant application not found'; end if;

  update public.profiles
  set role = 'merchant', phone = v_app.contact_phone, city = v_app.city
  where id = v_app.user_id;

  insert into public.stores(
    owner_id,name,slug,description,logo_url,contact_phone,city,address,latitude,longitude,status
  )
  values(
    v_app.user_id,v_app.proposed_store_name,p_store_slug,v_app.business_description,
    v_app.logo_url,v_app.contact_phone,v_app.city,v_app.street_address,
    v_app.latitude,v_app.longitude,'active'
  )
  returning id into v_store_id;

  update public.merchant_applications
  set status='approved',reviewed_by=auth.uid(),reviewed_at=now()
  where id=v_app.id;

  insert into public.notifications(user_id,title,body,kind,data)
  values(
    v_app.user_id,
    'تم اعتماد متجرك',
    'تمت الموافقة على بيانات متجرك. يمكنك الآن إضافة المنتجات وإدارة الطلبات.',
    'merchant_approved',
    jsonb_build_object('store_id',v_store_id,'license_document_path',v_app.license_document_url)
  );
  return v_store_id;
end;
$$;

create or replace function public.approve_courier_application(p_application_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_app public.courier_applications%rowtype;
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Administrator access required';
  end if;
  select * into v_app
  from public.courier_applications
  where id=p_application_id and status='pending'
  for update;
  if not found then raise exception 'Pending courier application not found'; end if;

  update public.profiles set role='courier',city=v_app.city where id=v_app.user_id;
  update public.courier_applications
  set status='approved',reviewed_by=auth.uid(),reviewed_at=now(),updated_at=now()
  where id=v_app.id;

  insert into public.notifications(user_id,title,body,kind,data)
  values(
    v_app.user_id,
    'تم اعتماد حساب المندوب',
    'تمت مراجعة وثائقك واعتماد حسابك. يمكنك الآن استقبال الشحنات.',
    'courier_approved',
    jsonb_build_object('application_id',v_app.id)
  );
  return v_app.user_id;
end;
$$;
revoke all on function public.approve_merchant_application(uuid,text) from public, anon;
grant execute on function public.approve_merchant_application(uuid,text) to authenticated;
revoke all on function public.approve_courier_application(uuid) from public, anon;
grant execute on function public.approve_courier_application(uuid) to authenticated;
