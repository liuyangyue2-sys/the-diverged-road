HTML 直传版使用说明

1. 先执行 supabase_setup_upload_ready.sql
   Supabase Dashboard -> SQL Editor -> New query -> Run

2. 创建管理员账号
   Supabase Dashboard -> Authentication -> Users -> Add user
   创建你的邮箱和密码。

3. 把管理员邮箱写入 admin_users
   SQL Editor 执行：

   insert into public.admin_users(user_id, email, note)
   select id, email, 'main admin'
   from auth.users
   where email = 'liuyangyue2@gmail.com'
   on conflict (user_id) do update
   set email = excluded.email, note = excluded.note;

4. 直接上传 loti_upload_ready_full.html
   这个文件已经是完整游戏 + 强制云同步 + 管理员后台。
   你可以把它改名为 index.html 上传部署。

5. 测试
   无痕窗口打开页面 -> 开始新人生 -> 选一题。
   Supabase Table Editor -> session_events 应该出现 start/choice。
   完成后 sessions_latest 应该出现最终结果。

注意：
别人以前未上传的本地数据，只有在他再次打开同一个域名时才能自动补传。
如果他再也不打开，服务器无法隔空读取他设备里的 localStorage。
