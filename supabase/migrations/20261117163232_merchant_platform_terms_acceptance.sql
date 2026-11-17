alter table public.merchant_program_acceptances add column if not exists platform_terms_accepted boolean not null default false;
create or replace function public.require_merchant_platform_terms_for_order_item()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 if not exists(select 1 from public.merchant_program_acceptances ma where ma.store_id=new.store_id and ma.owner_id=(select s.owner_id from public.stores s where s.id=new.store_id) and ma.platform_terms_accepted=true) then
  raise exception 'يجب على التاجر قبول شروط منصة تور بي قبل استقبال الطلبات';
 end if;
 return new;
end; $$;
revoke execute on function public.require_merchant_platform_terms_for_order_item() from public,anon,authenticated;
drop trigger if exists require_merchant_platform_terms_before_order_item on public.order_items;
create trigger require_merchant_platform_terms_before_order_item before insert on public.order_items
for each row execute function public.require_merchant_platform_terms_for_order_item();