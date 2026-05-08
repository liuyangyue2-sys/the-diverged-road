-- supabase_setup_upload_ready.sql
-- HTML 单文件直传版：强制云同步 + 管理员后台
-- Supabase Dashboard -> SQL Editor -> New query -> Run

create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  note text,
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;

drop policy if exists "admin user can read self" on public.admin_users;
create policy "admin user can read self"
on public.admin_users
for select
to authenticated
using (user_id = auth.uid());

create or replace function public.is_loti_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admin_users au
    where au.user_id = auth.uid()
  );
$$;

revoke all on function public.is_loti_admin() from public;
grant execute on function public.is_loti_admin() to authenticated;

create table if not exists public.sessions_latest (
  session_id text primary key,
  client_id text not null,
  last_event_id text,
  event_type text not null default 'snapshot',
  source text not null default 'html',
  app_version text not null default 'upload_ready_full_v1',
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

alter table public.sessions_latest enable row level security;

grant select, insert, update on public.sessions_latest to anon;
grant select, insert, update on public.sessions_latest to authenticated;

drop policy if exists "anon can insert latest sessions" on public.sessions_latest;
drop policy if exists "anon can update latest sessions" on public.sessions_latest;
drop policy if exists "admins can read latest sessions" on public.sessions_latest;
drop policy if exists "anon can upsert latest sessions insert" on public.sessions_latest;
drop policy if exists "anon can upsert latest sessions update" on public.sessions_latest;
drop policy if exists "temp anon can read latest sessions" on public.sessions_latest;

create policy "anon can insert latest sessions"
on public.sessions_latest
for insert
to anon, authenticated
with check (session_id is not null and client_id is not null);

create policy "anon can update latest sessions"
on public.sessions_latest
for update
to anon, authenticated
using (session_id is not null)
with check (session_id is not null and client_id is not null);

create policy "admins can read latest sessions"
on public.sessions_latest
for select
to authenticated
using (public.is_loti_admin());

create table if not exists public.session_events (
  id uuid primary key default gen_random_uuid(),
  client_event_id text not null unique,
  session_id text not null,
  client_id text not null,
  event_type text not null default 'snapshot',
  source text not null default 'html',
  app_version text not null default 'upload_ready_full_v1',
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

alter table public.session_events enable row level security;

grant select, insert on public.session_events to anon;
grant select, insert on public.session_events to authenticated;

drop policy if exists "anon can insert session events" on public.session_events;
drop policy if exists "admins can read session events" on public.session_events;
drop policy if exists "temp anon can read session events" on public.session_events;

create policy "anon can insert session events"
on public.session_events
for insert
to anon, authenticated
with check (
  client_event_id is not null
  and session_id is not null
  and client_id is not null
);

create policy "admins can read session events"
on public.session_events
for select
to authenticated
using (public.is_loti_admin());

create index if not exists idx_sessions_latest_updated_at on public.sessions_latest (updated_at desc);
create index if not exists idx_sessions_latest_client_id on public.sessions_latest (client_id);
create index if not exists idx_sessions_latest_final_ending_id on public.sessions_latest (final_ending_id);
create index if not exists idx_session_events_session_id_created_at on public.session_events (session_id, created_at desc);
create index if not exists idx_session_events_created_at on public.session_events (created_at desc);
create index if not exists idx_session_events_event_type on public.session_events (event_type);

-- 创建管理员账号后，把邮箱换成你的 Supabase Auth 用户邮箱，再执行：
-- insert into public.admin_users(user_id, email, note)
-- select id, email, 'main admin'
-- from auth.users
-- where email = 'liuyangyue2@gmail.com'
-- on conflict (user_id) do update
-- set email = excluded.email, note = excluded.note;
