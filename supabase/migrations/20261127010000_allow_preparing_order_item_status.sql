-- Permit the preparing stage already used by the merchant dashboard.
alter table public.order_items
  drop constraint if exists order_items_merchant_status_check;

alter table public.order_items
  add constraint order_items_merchant_status_check
  check (
    merchant_status = any (
      array[
        'new'::text,
        'accepted'::text,
        'preparing'::text,
        'ready_for_pickup'::text,
        'received_at_hub'::text,
        'cancelled'::text
      ]
    )
  );
