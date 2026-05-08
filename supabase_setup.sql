-- supabase_setup_auto_cloud_v6.sql
-- 全新干净表：避免旧 sessions_latest / session_events 表结构冲突
-- Supabase Dashboard -> SQL Editor -> New query -> Run

create extension if not exists pgcrypto;

create table if not exists public.loti_admin_users_v6 (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  note text,
  created_at timestamptz not null default now()
);

alter table public.loti_admin_users_v6 enable row level security;

drop policy if exists "admin can read self v6" on public.loti_admin_users_v6;
create policy "admin can read self v6"
on public.loti_admin_users_v6
for select
to authenticated
using (user_id = auth.uid());

create or replace function public.is_loti_admin_v6()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.loti_admin_users_v6 au
    where au.user_id = auth.uid()
  );
$$;

revoke all on function public.is_loti_admin_v6() from public;
grant execute on function public.is_loti_admin_v6() to authenticated;

create table if not exists public.loti_sessions_latest_v6 (
  session_id text primary key,
  client_id text not null,
  last_event_id text,
  event_type text not null default 'snapshot',
  source text not null default 'html',
  app_version text not null default 'upload_ready_auto_cloud_v6',
  answer_count integer not null default 0,
  final_ending_id text default '',
  final_ending_name text default '',
  final_ending_type text default '',
  route_key text default '',
  relationship_route text default '',
  child_route text default '',
  parenting_route text default '',
  illegal_count integer not null default 0,
  grey_count integer not null default 0,
  stats jsonb not null default '{}'::jsonb,
  answer_logs jsonb not null default '[]'::jsonb,
  raw jsonb not null default '{}'::jsonb,
  user_agent text default '',
  page_url text default '',
  started_at timestamptz,
  finished_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.loti_sessions_latest_v6 enable row level security;

grant select, insert, update on public.loti_sessions_latest_v6 to anon;
grant select, insert, update on public.loti_sessions_latest_v6 to authenticated;

drop policy if exists "anon can insert latest v6" on public.loti_sessions_latest_v6;
drop policy if exists "anon can update latest v6" on public.loti_sessions_latest_v6;
drop policy if exists "admins can read latest v6" on public.loti_sessions_latest_v6;

create policy "anon can insert latest v6"
on public.loti_sessions_latest_v6
for insert
to anon, authenticated
with check (session_id is not null and client_id is not null);

create policy "anon can update latest v6"
on public.loti_sessions_latest_v6
for update
to anon, authenticated
using (session_id is not null)
with check (session_id is not null and client_id is not null);

create policy "admins can read latest v6"
on public.loti_sessions_latest_v6
for select
to authenticated
using (public.is_loti_admin_v6());

create table if not exists public.loti_session_events_v6 (
  id uuid primary key default gen_random_uuid(),
  client_event_id text not null unique,
  session_id text not null,
  client_id text not null,
  event_type text not null default 'snapshot',
  source text not null default 'html',
  app_version text not null default 'upload_ready_auto_cloud_v6',
  answer_count integer not null default 0,
  final_ending_id text default '',
  final_ending_name text default '',
  final_ending_type text default '',
  route_key text default '',
  relationship_route text default '',
  child_route text default '',
  parenting_route text default '',
  illegal_count integer not null default 0,
  grey_count integer not null default 0,
  stats jsonb not null default '{}'::jsonb,
  answer_logs jsonb not null default '[]'::jsonb,
  raw jsonb not null default '{}'::jsonb,
  user_agent text default '',
  page_url text default '',
  created_at timestamptz not null default now()
);

alter table public.loti_session_events_v6 enable row level security;

grant select, insert on public.loti_session_events_v6 to anon;
grant select, insert on public.loti_session_events_v6 to authenticated;

drop policy if exists "anon can insert events v6" on public.loti_session_events_v6;
drop policy if exists "admins can read events v6" on public.loti_session_events_v6;

create policy "anon can insert events v6"
on public.loti_session_events_v6
for insert
to anon, authenticated
with check (
  client_event_id is not null
  and session_id is not null
  and client_id is not null
);

create policy "admins can read events v6"
on public.loti_session_events_v6
for select
to authenticated
using (public.is_loti_admin_v6());

create index if not exists idx_loti_sessions_latest_v6_updated_at on public.loti_sessions_latest_v6 (updated_at desc);
create index if not exists idx_loti_sessions_latest_v6_client_id on public.loti_sessions_latest_v6 (client_id);
create index if not exists idx_loti_sessions_latest_v6_final_ending_id on public.loti_sessions_latest_v6 (final_ending_id);
create index if not exists idx_loti_session_events_v6_session_id_created_at on public.loti_session_events_v6 (session_id, created_at desc);
create index if not exists idx_loti_session_events_v6_created_at on public.loti_session_events_v6 (created_at desc);
create index if not exists idx_loti_session_events_v6_event_type on public.loti_session_events_v6 (event_type);

-- 创建管理员账号后执行，邮箱可改成你的：
insert into public.loti_admin_users_v6(user_id, email, note)
select id, email, 'main admin'
from auth.users
where email = 'liuyangyue2@gmail.com'
on conflict (user_id) do update
set email = excluded.email,
    note = excluded.note;
