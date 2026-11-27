-- Enable Postgres Changes for the tables used by the TOOR-BE dashboards.
-- Idempotent so it is safe after the publication was configured manually.
DO $$
DECLARE
  table_name text;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    FOREACH table_name IN ARRAY ARRAY[
      'profiles',
      'stores',
      'products',
      'orders',
      'shipments',
      'order_items',
      'order_events',
      'support_reports',
      'merchant_applications',
      'courier_applications',
      'coupons',
      'settlements',
      'notifications',
      'loyalty_rewards'
    ]
    LOOP
      IF to_regclass('public.' || table_name) IS NOT NULL
         AND NOT EXISTS (
           SELECT 1
           FROM pg_publication_tables
           WHERE pubname = 'supabase_realtime'
             AND schemaname = 'public'
             AND tablename = table_name
         ) THEN
        EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', table_name);
      END IF;
    END LOOP;
  END IF;
END;
$$;
