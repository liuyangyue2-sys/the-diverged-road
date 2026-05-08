# 人生算法：抉择之书｜GitHub H5 + Supabase 强制云同步版 v4

## 包里有什么

```
index.html             # 玩家 + 管理员后台（主入口）
loti_final.html        # 同上的备份/独立版本
supabase_setup.sql     # Supabase 一次性初始化脚本
README.md              # 你正在看
BALANCE_REPORT.md      # 数值平衡说明
```

两份 HTML 完全等价，部署其中任意一份都行。

## 部署 5 步

### 1) Supabase 项目初始化
登录 Supabase Dashboard → 新建项目 → SQL Editor → 把 `supabase_setup.sql` 整段粘进去执行一次。会建好这三张表：
- `sessions_latest`：玩家最终数据（一局一行，主表）
- `session_events`：稀疏事件采样（开始/结束/每 8 题）
- `admin_users`：管理员白名单

### 2) 创建管理员账号
Supabase → Authentication → Users → "Add user" → 邮箱 + 密码。建好后复制那个 User UID。

### 3) 把 UID 注册成管理员
回到 SQL Editor 执行：
```sql
insert into public.admin_users (user_id, note)
values ('粘贴你的 UID', 'main admin')
on conflict (user_id) do update set note = excluded.note;
```

### 4) 把 Project URL 和 anon key 写进 HTML（如需）
默认配置已经写死在 `index.html` / `loti_final.html` 里：
```
DEFAULT_SUPABASE_URL      = https://gprhouosljuonstjopct.supabase.co
DEFAULT_SUPABASE_ANON_KEY = sb_publishable_... 
```
如果你用的是**自己的 Supabase 项目**，去 Settings → API：
- Project URL：拷贝 → 替换 `DEFAULT_SUPABASE_URL`
- Key：**优先用 legacy `anon` JWT**（`eyJ...` 开头那条），替换 `DEFAULT_SUPABASE_ANON_KEY`。新版 `sb_publishable_*` 也支持，但部分 CDN 缓存的 supabase-js 老版本会拒。

两个文件都要改，搜 `DEFAULT_SUPABASE_URL` 和 `DEFAULT_SUPABASE_ANON_KEY` 就能定位。

### 5) 推到 GitHub Pages
把整个文件夹推到 GitHub 仓库 → Settings → Pages → 选分支 → Save。访问域名就能玩。

## 验证云同步是否真的通了

打开你的 H5 页面 → 进**后台**（首页"后台"按钮）→ 输本地口令 `0427` → 输 Supabase 管理员邮箱密码 → 点 **登录并读取云端数据**。

如果"云端参与局数"是 0，按下 **云同步诊断** 按钮，弹窗会逐项告诉你哪一步坏了：
- `SDK 加载: ❌` → CDN 都不通，看玩家网络
- `SUPABASE_ENABLED: ❌` → URL 或 key 没填对
- `匿名写入测试: ❌ row-level security` → key 角色不对，换 legacy anon JWT
- `匿名写入测试: ❌ Invalid API key` → key 拷错或过期
- `管理员读取测试: ❌` → 多半是 admin_users 没注册你的 UID，回到第 3 步
- `本地总局数: 0` → 这台设备没玩过，没东西可补传

## 数据自动上云的工作机制

**新玩家完全无感、自动上云**

每个选项点击 → `syncStateToSupabase('answer')` 实时写入。结局触发时还会：
1. 用 `fetch(..., { keepalive: true })` 直接 POST 一次，浏览器保证页面卸载也能完成
2. 同时 `await` 一次走 SDK 的 upsert，等同步成功才算结束
3. 同步成功的本地局会被打上 `cloudSynced: true` 标记

**老玩家本地历史也会自动上云**

页面加载完 1.5 秒后，后台静默扫一遍 localStorage，所有 `finalEndingId` 存在但没 `cloudSynced` 的旧局会逐条 upsert 上去。失败的不动标记，下次自动再试。

**云同步保活机制（页面只要被打开过就极难掉）**
- supabase-js 三 CDN 接力（jsdelivr / unpkg / bootcdn）
- 每 2 分钟在后台再扫一次失败的局
- 网络从离线恢复时立刻重试
- 标签页从后台切回前台时立刻重试  
- 关页面时 `beforeunload` + `pagehide` 触发最后一次 keepalive 兜底

**注意：纯静态 H5 无法做到"页面没打开也能补传"。**这是浏览器同源沙盒的物理限制 —— localStorage 只能在那个域名页面活着的时候被读。新玩家不需要担心（实时上云），只有云同步功能上线之前已经存了本地数据的老玩家，必须至少打开一次页面（剩下的全自动）。

## 后台你能看到什么

`sessions_latest` 一局一行，包含：
- `session_id` / `client_id` / `event_type`
- `final_ending_id` / `final_ending_name` / `final_ending_type`
- `route_key` / `relationship_route` / `child_route` / `parenting_route`
- `illegal_count` / `grey_count`
- `stats`（四维数值）
- `answer_logs`（完整答题记录 JSONB）
- `raw`（完整 state 对象，备份兜底）
- `updated_at` / `created_at`

后台会自动统计：云端参与局数、违法用户数、违法选择占比、结局分布、婚恋路径、子女路径分布、最近 20 局明细。

## 后台按钮一览

- **登录并读取云端数据** / **刷新云端数据** / **退出云后台**：管理员 Supabase 操作
- **导出云端 JSON**：把当前已读取的云端数据导出本地文件
- **导出本地 JSON**：导出这台设备的本地存档
- **导入本地 JSON**：从备份文件恢复本地存档
- **本地历史补传到云**：手动触发一次完整本地→云端同步
- **云同步诊断**：一键自检 SDK / 配置 / 写入 / 读取 / admin 注册状态

## 安全提醒

- 默认配置文件里只放 `anon` 或 `publishable` key，**绝对不要把 `service_role` key 写进 HTML**，那是后端密钥，泄露等于把库交出去。
- 后台口令 `0427` 只是前端访问门槛，真正的权限墙在 Supabase RLS。RLS 已配置：匿名只能写 `sessions_latest` / `session_events`，不能读；只有 `admin_users` 表里的 UID 能读云端数据。
- `admin_users` 表本身只允许已登录用户读自己那一行，避免管理员名单被任何人拉取。

## v4 更新日志

- 强制多 CDN 加载 supabase-js 2.45.4，单点 CDN 故障不再导致云同步失效
- `finishSession` 改为 async + `keepalive` 双兜底，结局后立刻关页面也不丢数据
- 新增 `cloudSynced` 标记，已上云的局不会重复同步
- 新增 `autoBackfillOnce()`：进页面 1.5s 自动补传本地历史，失败自愈
- 新增周期重试（每 2 分钟）+ 网络恢复 + 标签页可见 + 页面卸载多重触发
- 后台新增"本地历史补传到云" / "云同步诊断"两个按钮
- RLS 与 SQL schema 与 v3 一致，无需重新执行 setup 脚本
