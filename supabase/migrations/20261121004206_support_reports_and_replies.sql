create table if not exists public.support_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  subject text not null check (char_length(trim(subject)) between 4 and 160),
  category text not null default 'general' check (category in ('general','order','product','store','courier','payment','technical','abuse')),
  description text not null check (char_length(trim(description)) between 10 and 5000),
  order_id uuid null references public.orders(id) on delete set null,
  product_id uuid null references public.products(id) on delete set null,
  store_id uuid null references public.stores(id) on delete set null,
  status text not null default 'open' check (status in ('open','in_progress','waiting_user','resolved','closed')),
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  assigned_admin_id uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz null
);
create table if not exists public.support_report_messages (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.support_reports(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  message text not null check (char_length(trim(message)) between 1 and 5000),
  is_internal boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists support_reports_reporter_created_idx on public.support_reports(reporter_id, created_at desc);
create index if not exists support_reports_status_updated_idx on public.support_reports(status, updated_at desc);
create index if not exists support_report_messages_report_created_idx on public.support_report_messages(report_id, created_at);
alter table public.support_reports enable row level security;
alter table public.support_report_messages enable row level security;
drop policy if exists support_reports_read_participant_or_admin on public.support_reports;
create policy support_reports_read_participant_or_admin on public.support_reports for select to authenticated
using (reporter_id = (select auth.uid()) or exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));
drop policy if exists support_reports_create_own on public.support_reports;
create policy support_reports_create_own on public.support_reports for insert to authenticated
with check (reporter_id = (select auth.uid()) and status = 'open' and assigned_admin_id is null);
drop policy if exists support_reports_admin_update on public.support_reports;
create policy support_reports_admin_update on public.support_reports for update to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'))
with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));
drop policy if exists support_report_messages_read_visible on public.support_report_messages;
create policy support_report_messages_read_visible on public.support_report_messages for select to authenticated
using ((not is_internal and exists (select 1 from public.support_reports r where r.id = report_id and r.reporter_id = (select auth.uid())))
or exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));
drop policy if exists support_report_messages_insert_participant on public.support_report_messages;
create policy support_report_messages_insert_participant on public.support_report_messages for insert to authenticated
with check (sender_id = (select auth.uid()) and (
(not is_internal and exists (select 1 from public.support_reports r where r.id = report_id and r.reporter_id = (select auth.uid()) and r.status not in ('resolved','closed')))
or exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin')));
revoke all on public.support_reports from anon;
revoke all on public.support_report_messages from anon;
grant select, insert, update on public.support_reports to authenticated;
grant select, insert on public.support_report_messages to authenticated;
