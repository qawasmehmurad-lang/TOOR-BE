revoke all on function public.buyer_set_order_delivery_speed(uuid,text) from anon, public;
grant execute on function public.buyer_set_order_delivery_speed(uuid,text) to authenticated;

revoke all on function public.get_my_deliveries() from anon, public;
grant execute on function public.get_my_deliveries() to authenticated;

revoke all on function public.courier_update_shipment(uuid,text,text,text) from anon, public;
grant execute on function public.courier_update_shipment(uuid,text,text,text) to authenticated;