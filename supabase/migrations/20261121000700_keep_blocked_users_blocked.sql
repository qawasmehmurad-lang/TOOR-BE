-- Do not silently unblock a buyer while promoting them to courier.
create or replace function public.admin_assign_courier(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Administrator access required';
  end if;

  update public.profiles
  set role = 'courier', updated_at = now()
  where id = p_user_id and role = 'buyer' and is_blocked = false;

  if not found then
    raise exception 'Only an active buyer account can be assigned as a courier';
  end if;

  insert into public.notifications(user_id, title, body, kind)
  values (
    p_user_id,
    'تم تفعيل حساب مندوب التوصيل',
    'تم اعتماد حسابك كمندوب توصيل في منصة تور بي.',
    'courier_approved'
  );

  return true;
end;
$$;

revoke all on function public.admin_assign_courier(uuid) from public, anon;
grant execute on function public.admin_assign_courier(uuid) to authenticated;
