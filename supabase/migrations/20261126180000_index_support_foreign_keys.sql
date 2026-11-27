-- Add covering indexes for support-system foreign keys flagged by Supabase advisors.
-- These indexes are additive and do not alter existing rows or access policies.
create index if not exists support_report_messages_sender_id_idx
  on public.support_report_messages (sender_id);

create index if not exists support_reports_assigned_admin_id_idx
  on public.support_reports (assigned_admin_id);

create index if not exists support_reports_order_id_idx
  on public.support_reports (order_id);

create index if not exists support_reports_product_id_idx
  on public.support_reports (product_id);

create index if not exists support_reports_store_id_idx
  on public.support_reports (store_id);
