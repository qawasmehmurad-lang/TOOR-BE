-- Allow active public campaigns to be previewed and redeemed by every signed-in account role.
-- The coupon assignment table remains available for targeted notifications and administration,
-- but an existing assignment list no longer acts as an access restriction for an active campaign.
do $migration$
declare
  v_definition text;
begin
  select pg_get_functiondef('public.preview_coupon(text,jsonb)'::regprocedure)
    into v_definition;
  v_definition := replace(
    v_definition,
    ' if exists(select 1 from public.coupon_assignments ca where ca.coupon_id=v_coupon.id) and not exists(select 1 from public.coupon_assignments ca where ca.coupon_id=v_coupon.id and ca.user_id=v_user) then raise exception ''هذا الكوبون مخصص لمستخدمين محددين''; end if;',
    ''
  );
  execute v_definition;

  select pg_get_functiondef('public.place_order(uuid,jsonb,text,text)'::regprocedure)
    into v_definition;
  v_definition := replace(
    v_definition,
    '  if exists(select 1 from public.coupon_assignments ca where ca.coupon_id=v_coupon.id) and not exists(select 1 from public.coupon_assignments ca where ca.coupon_id=v_coupon.id and ca.user_id=v_user) then raise exception ''هذا الكوبون مخصص لمستخدمين محددين''; end if;',
    ''
  );
  execute v_definition;
end
$migration$;
