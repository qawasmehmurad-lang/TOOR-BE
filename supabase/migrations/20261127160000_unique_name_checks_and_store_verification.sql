alter table public.stores
  add column if not exists alternate_phone text,
  add column if not exists category_id uuid references public.categories(id),
  add column if not exists license_document_url text,
  add column if not exists is_verified boolean not null default false;

create or replace function public.is_profile_name_available(p_full_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select nullif(btrim(coalesce(p_full_name,'')),'') is not null
    and length(btrim(p_full_name)) between 2 and 60
    and not exists (
      select 1 from public.profiles p
      where lower(btrim(p.full_name)) = lower(btrim(p_full_name))
    );
$$;
revoke all on function public.is_profile_name_available(text) from public;
grant execute on function public.is_profile_name_available(text) to anon, authenticated;

create or replace function public.is_store_name_available(p_store_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select nullif(btrim(coalesce(p_store_name,'')),'') is not null
    and length(btrim(p_store_name)) between 2 and 80
    and not exists (
      select 1 from public.stores s
      where lower(btrim(s.name)) = lower(btrim(p_store_name))
    )
    and not exists (
      select 1 from public.merchant_applications a
      where a.status = 'pending'
        and lower(btrim(a.proposed_store_name)) = lower(btrim(p_store_name))
    );
$$;
revoke all on function public.is_store_name_available(text) from public;
grant execute on function public.is_store_name_available(text) to anon, authenticated;

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
    owner_id,name,slug,description,logo_url,contact_phone,alternate_phone,city,address,
    latitude,longitude,category_id,license_document_url,is_verified,status
  )
  values(
    v_app.user_id,v_app.proposed_store_name,p_store_slug,v_app.business_description,
    v_app.logo_url,v_app.contact_phone,v_app.alternate_phone,v_app.city,v_app.street_address,
    v_app.latitude,v_app.longitude,v_app.category_id,v_app.license_document_url,
    v_app.license_document_url is not null,'active'
  )
  returning id into v_store_id;

  update public.merchant_applications
  set status='approved',reviewed_by=auth.uid(),reviewed_at=now()
  where id=v_app.id;

  insert into public.notifications(user_id,title,body,kind,data)
  values(
    v_app.user_id,
    case when v_app.license_document_url is not null then 'تم اعتماد متجرك وتوثيقه' else 'تم اعتماد متجرك' end,
    case when v_app.license_document_url is not null
      then 'تمت الموافقة على المتجر وشهادة الترخيص، وحصل متجرك على علامة التوثيق الزرقاء.'
      else 'تمت الموافقة على بيانات متجرك. يمكنك الآن إضافة المنتجات وإدارة الطلبات.'
    end,
    'merchant_approved',
    jsonb_build_object('store_id',v_store_id,'verified',v_app.license_document_url is not null)
  );
  return v_store_id;
end;
$$;
revoke all on function public.approve_merchant_application(uuid,text) from public, anon;
grant execute on function public.approve_merchant_application(uuid,text) to authenticated;
