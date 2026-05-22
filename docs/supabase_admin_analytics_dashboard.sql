-- YSMA management analytics dashboard
-- Run this in the Supabase SQL editor. It keeps analytics outside the visitor
-- app while still allowing authenticated app users to insert activity events.

create table if not exists public.admin_activity_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null check (event_type in ('view', 'share', 'favorite')),
  artwork_title text not null,
  visitor_name text,
  visitor_email text,
  visitor_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.admin_activity_events enable row level security;

drop policy if exists "Visitors can insert analytics events"
  on public.admin_activity_events;

create policy "Visitors can insert analytics events"
  on public.admin_activity_events
  for insert
  to authenticated
  with check (auth.uid() = visitor_id or visitor_id is null);

drop policy if exists "Visitors cannot read analytics events"
  on public.admin_activity_events;

create policy "Visitors cannot read analytics events"
  on public.admin_activity_events
  for select
  to authenticated
  using (false);

create or replace view public.admin_analytics_overview as
select
  count(*) filter (where event_type = 'view') as total_views,
  count(*) filter (where event_type = 'share') as total_shares,
  count(*) filter (where event_type = 'favorite') as total_favourites,
  count(distinct coalesce(visitor_id::text, visitor_email, visitor_name)) as total_visitors,
  min(created_at) as first_event_at,
  max(created_at) as latest_event_at
from public.admin_activity_events;

create or replace view public.admin_artwork_engagement as
select
  artwork_title,
  count(*) filter (where event_type = 'view') as views,
  count(*) filter (where event_type = 'share') as shares,
  count(*) filter (where event_type = 'favorite') as favourites,
  count(*) as total_events,
  count(distinct coalesce(visitor_id::text, visitor_email, visitor_name)) as unique_visitors,
  max(created_at) as latest_event_at
from public.admin_activity_events
group by artwork_title
order by total_events desc, views desc, artwork_title;

create or replace view public.admin_daily_activity as
select
  date_trunc('day', created_at)::date as activity_date,
  count(*) filter (where event_type = 'view') as views,
  count(*) filter (where event_type = 'share') as shares,
  count(*) filter (where event_type = 'favorite') as favourites,
  count(distinct coalesce(visitor_id::text, visitor_email, visitor_name)) as visitors
from public.admin_activity_events
group by activity_date
order by activity_date desc;

create or replace view public.admin_recent_activity as
select
  created_at,
  event_type,
  artwork_title,
  coalesce(nullif(visitor_name, ''), 'Visitor') as visitor_name,
  visitor_email,
  visitor_id
from public.admin_activity_events
order by created_at desc
limit 200;
