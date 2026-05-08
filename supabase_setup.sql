-- Supabase setup for 《人生算法：抉择之书》 H5 云同步版 v4 强制云同步 + 全角色兼容
-- 在 Supabase Dashboard → SQL Editor 中整段执行（重复执行也安全，所有 policy 都会先 drop 再建）。
-- 主表：sessions_latest；事件采样表：session_events；管理员表：admin_users。
-- 这一版 v4 的关键变化：写入策略改为 `to public`，覆盖 anon / authenticated / service_role / 任何新版 API key 角色，
-- 解决 iPad 无痕 / 微信内置浏览器 / 部分新版 publishable key 角色映射不到 anon 导致 RLS 拒写的问题。

-- =========================================================
-- 1) 表结构（幂等）
-- =========================================================
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

-- =========================================================
-- 2) 启用 RLS
-- =========================================================
alter table public.sessions_latest enable row level security;
alter table public.session_events enable row level security;
alter table public.admin_users enable row level security;

-- =========================================================
-- 3) sessions_latest 策略
-- =========================================================
drop policy if exists "anon can insert latest sessions" on public.sessions_latest;
drop policy if exists "anon can update latest sessions" on public.sessions_latest;
drop policy if exists "anon can upsert latest sessions insert" on public.sessions_latest;
drop policy if exists "anon can upsert latest sessions update" on public.sessions_latest;
drop policy if exists "public can upsert sessions insert" on public.sessions_latest;
drop policy if exists "public can upsert sessions update" on public.sessions_latest;
drop policy if exists "admins can read latest sessions" on public.sessions_latest;

-- 写入：放开给 public，所有角色（anon / authenticated / 新版 publishable key 派生角色）都能 INSERT/UPSERT
create policy "public can upsert sessions insert"
on public.sessions_latest
for insert
to public
with check (true);

create policy "public can upsert sessions update"
on public.sessions_latest
for update
to public
using (true)
with check (true);

-- 读取：只允许 admin_users 白名单里的人
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

-- =========================================================
-- 4) session_events 策略
-- =========================================================
drop policy if exists "anon and auth can insert session events" on public.session_events;
drop policy if exists "anon can insert session events" on public.session_events;
drop policy if exists "public can insert session events" on public.session_events;
drop policy if exists "admins can read session events" on public.session_events;

create policy "public can insert session events"
on public.session_events
for insert
to public
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

-- =========================================================
-- 5) admin_users 策略
-- =========================================================
drop policy if exists "admins can read own admin row" on public.admin_users;
drop policy if exists "admins can read admin users" on public.admin_users;

create policy "admins can read own admin row"
on public.admin_users
for select
to authenticated
using (user_id = auth.uid());

-- =========================================================
-- 6) GRANT —— 角色级别的最低权限
-- =========================================================
grant usage on schema public to anon, authenticated;
grant insert, update on public.sessions_latest to anon, authenticated;
grant select on public.sessions_latest to authenticated;
grant insert on public.session_events to anon, authenticated;
grant select on public.session_events to authenticated;
grant select on public.admin_users to authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;

-- =========================================================
-- 7) 默认管理员注册（你的 UID 已写死）
--    换人或加人就在下面加 insert ... on conflict 再跑一次。
-- =========================================================
insert into public.admin_users (user_id, note)
values ('df1bf1f7-d97d-4f73-a186-0154a79b6612', 'main admin')
on conflict (user_id) do update set note = excluded.note;

-- =========================================================
-- 8) 自检（执行后看返回值，全是 t/true 就对了）
-- =========================================================
select
  (select count(*) from pg_policies where schemaname='public' and tablename='sessions_latest') as sessions_latest_policies,
  (select count(*) from pg_policies where schemaname='public' and tablename='session_events')   as session_events_policies,
  (select count(*) from pg_policies where schemaname='public' and tablename='admin_users')      as admin_users_policies,
  (select count(*) from public.admin_users) as admin_users_rows;
