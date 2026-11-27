create index if not exists merchant_applications_category_id_idx on public.merchant_applications(category_id);
create index if not exists stores_category_id_idx on public.stores(category_id);
create index if not exists courier_applications_reviewed_by_idx on public.courier_applications(reviewed_by);

create or replace function private.registration_profile_name_available(p_full_name text)
returns boolean language sql stable security definer set search_path = ''
as $$
  select nullif(btrim(coalesce(p_full_name,'')),'') is not null
    and length(btrim(p_full_name)) between 2 and 60
    and not exists (select 1 from public.profiles p where lower(btrim(p.full_name))=lower(btrim(p_full_name)));
$$;
create or replace function public.is_profile_name_available(p_full_name text)
returns boolean language sql stable security invoker set search_path = ''
as $$ select private.registration_profile_name_available(p_full_name); $$;
revoke all on function private.registration_profile_name_available(text) from public;
grant usage on schema private to anon,authenticated;
grant execute on function private.registration_profile_name_available(text) to anon,authenticated;
revoke all on function public.is_profile_name_available(text) from public;
grant execute on function public.is_profile_name_available(text) to anon,authenticated;

create or replace function private.registration_store_name_available(p_store_name text)
returns boolean language sql stable security definer set search_path = ''
as $$
  select nullif(btrim(coalesce(p_store_name,'')),'') is not null
    and length(btrim(p_store_name)) between 2 and 80
    and not exists (select 1 from public.stores s where lower(btrim(s.name))=lower(btrim(p_store_name)))
    and not exists (select 1 from public.merchant_applications a where a.status='pending' and lower(btrim(a.proposed_store_name))=lower(btrim(p_store_name)));
$$;
create or replace function public.is_store_name_available(p_store_name text)
returns boolean language sql stable security invoker set search_path = ''
as $$ select private.registration_store_name_available(p_store_name); $$;
revoke all on function private.registration_store_name_available(text) from public;
grant execute on function private.registration_store_name_available(text) to anon,authenticated;
revoke all on function public.is_store_name_available(text) from public;
grant execute on function public.is_store_name_available(text) to anon,authenticated;

create or replace function private.approve_merchant_application_impl(p_application_id uuid,p_store_slug text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_app public.merchant_applications%rowtype; v_store_id uuid;
begin
  if auth.uid() is null or not private.is_admin() then raise exception 'Administrator access required'; end if;
  select * into v_app from public.merchant_applications where id=p_application_id and status='pending' for update;
  if not found then raise exception 'Pending merchant application not found'; end if;
  update public.profiles set role='merchant',phone=v_app.contact_phone,city=v_app.city where id=v_app.user_id;
  insert into public.stores(owner_id,name,slug,description,logo_url,contact_phone,alternate_phone,city,address,latitude,longitude,category_id,license_document_url,is_verified,status)
  values(v_app.user_id,v_app.proposed_store_name,p_store_slug,v_app.business_description,v_app.logo_url,v_app.contact_phone,v_app.alternate_phone,v_app.city,v_app.street_address,v_app.latitude,v_app.longitude,v_app.category_id,v_app.license_document_url,v_app.license_document_url is not null,'active')
  returning id into v_store_id;
  update public.merchant_applications set status='approved',reviewed_by=auth.uid(),reviewed_at=now() where id=v_app.id;
  insert into public.notifications(user_id,title,body,kind,data)
  values(v_app.user_id,case when v_app.license_document_url is not null then 'تم اعتماد متجرك وتوثيقه' else 'تم اعتماد متجرك' end,
    case when v_app.license_document_url is not null then 'تمت الموافقة على المتجر وشهادة الترخيص، وحصل متجرك على علامة التوثيق الزرقاء.' else 'تمت الموافقة على بيانات متجرك. يمكنك الآن إضافة المنتجات وإدارة الطلبات.' end,
    'merchant_approved',jsonb_build_object('store_id',v_store_id,'verified',v_app.license_document_url is not null));
  return v_store_id;
end;
$$;
create or replace function public.approve_merchant_application(p_application_id uuid,p_store_slug text)
returns uuid language sql security invoker set search_path = ''
as $$ select private.approve_merchant_application_impl(p_application_id,p_store_slug); $$;
revoke all on function private.approve_merchant_application_impl(uuid,text) from public,anon;
grant execute on function private.approve_merchant_application_impl(uuid,text) to authenticated;
revoke all on function public.approve_merchant_application(uuid,text) from public,anon;
grant execute on function public.approve_merchant_application(uuid,text) to authenticated;

create or replace function private.approve_courier_application_impl(p_application_id uuid)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_app public.courier_applications%rowtype;
begin
  if auth.uid() is null or not private.is_admin() then raise exception 'Administrator access required'; end if;
  select * into v_app from public.courier_applications where id=p_application_id and status='pending' for update;
  if not found then raise exception 'Pending courier application not found'; end if;
  update public.profiles set role='courier',city=v_app.city where id=v_app.user_id;
  update public.courier_applications set status='approved',reviewed_by=auth.uid(),reviewed_at=now(),updated_at=now() where id=v_app.id;
  insert into public.notifications(user_id,title,body,kind,data)
  values(v_app.user_id,'تم اعتماد حساب المندوب','تمت مراجعة وثائقك واعتماد حسابك. يمكنك الآن استقبال الشحنات.','courier_approved',jsonb_build_object('application_id',v_app.id));
  return v_app.user_id;
end;
$$;
create or replace function public.approve_courier_application(p_application_id uuid)
returns uuid language sql security invoker set search_path = ''
as $$ select private.approve_courier_application_impl(p_application_id); $$;
revoke all on function private.approve_courier_application_impl(uuid) from public,anon;
grant execute on function private.approve_courier_application_impl(uuid) to authenticated;
revoke all on function public.approve_courier_application(uuid) from public,anon;
grant execute on function public.approve_courier_application(uuid) to authenticated;
