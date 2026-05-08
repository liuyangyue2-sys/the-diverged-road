-- Supabase setup for 《人生算法：抉择之书》 H5 云同步版 v3 强制云同步
-- 在 Supabase Dashboard → SQL Editor 中整段执行。
-- 主表：sessions_latest；事件采样表：session_events；管理员表：admin_users。

create table if not exists public.sessions_latest (
  session_id text primary key,
  client_id text not null,
  event_type text default 'snapshot',
  answer_count int default 0,
  final_ending_id text,
  final_ending_name text,
  final_ending_type text,
  route_key text,
  relationship_route text,
  child_route text,
  parenting_route text,
  illegal_count int default 0,
  grey_count int default 0,
  stats jsonb default '{}'::jsonb,
  answer_logs jsonb default '[]'::jsonb,
  raw jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now(),
  created_at timestamptz default now()
);

create table if not exists public.session_events (
  id bigint generated always as identity primary key,
  session_id text not null,
  client_id text not null,
  event_type text default 'snapshot',
  answer_count int default 0,
  final_ending_id text,
  final_ending_name text,
  final_ending_type text,
  route_key text,
  relationship_route text,
  child_route text,
  parenting_route text,
  illegal_count int default 0,
  grey_count int default 0,
  stats jsonb default '{}'::jsonb,
  answer_logs jsonb default '[]'::jsonb,
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz default now()
);

create table if not exists public.admin_users (
  user_id uuid primary key,
  note text,
  created_at timestamptz default now()
);

alter table public.sessions_latest enable row level security;
alter table public.session_events enable row level security;
alter table public.admin_users enable row level security;

drop policy if exists "anon can insert latest sessions" on public.sessions_latest;
drop policy if exists "anon can update latest sessions" on public.sessions_latest;
drop policy if exists "anon can upsert latest sessions insert" on public.sessions_latest;
drop policy if exists "anon can upsert latest sessions update" on public.sessions_latest;
drop policy if exists "admins can read latest sessions" on public.sessions_latest;

create policy "anon can upsert latest sessions insert"
on public.sessions_latest
for insert
to anon, authenticated
with check (true);

create policy "anon can upsert latest sessions update"
on public.sessions_latest
for update
to anon, authenticated
using (true)
with check (true);

create policy "admins can read latest sessions"
on public.sessions_latest
for select
to authenticated
using (
  exists (
    select 1 from public.admin_users
    where admin_users.user_id = auth.uid()
  )
);

drop policy if exists "anon and auth can insert session events" on public.session_events;
drop policy if exists "anon can insert session events" on public.session_events;
drop policy if exists "admins can read session events" on public.session_events;

create policy "anon and auth can insert session events"
on public.session_events
for insert
to anon, authenticated
with check (true);

create policy "admins can read session events"
on public.session_events
for select
to authenticated
using (
  exists (
    select 1 from public.admin_users
    where admin_users.user_id = auth.uid()
  )
);

drop policy if exists "admins can read own admin row" on public.admin_users;
drop policy if exists "admins can read admin users" on public.admin_users;

create policy "admins can read own admin row"
on public.admin_users
for select
to authenticated
using (user_id = auth.uid());

grant usage on schema public to anon, authenticated;
grant insert, update on public.sessions_latest to anon, authenticated;
grant select on public.sessions_latest to authenticated;
grant insert on public.session_events to anon, authenticated;
grant select on public.session_events to authenticated;
grant select on public.admin_users to authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;

-- 创建管理员账号后，把 Authentication → Users 里的 User UID 填入下面这句再执行：
-- insert into public.admin_users (user_id, note)
-- values ('替换成你的管理员 User UID', 'main admin')
-- on conflict (user_id) do update set note = excluded.note;
