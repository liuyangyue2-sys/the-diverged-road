# 人生算法：抉择之书｜GitHub H5 + Supabase 云同步版 v2

## 先做什么

1. 在 Supabase 创建项目。
2. 打开 `supabase_setup.sql`，在 SQL Editor 里整段执行。
3. 在 Supabase Authentication 里创建管理员账号，复制 User UID。
4. 在 SQL Editor 执行：

```sql
insert into public.admin_users (user_id, note)
values ('你的管理员 User UID', 'main admin')
on conflict (user_id) do update set note = excluded.note;
```

5. 上传 `index.html` 到 GitHub Pages。
6. 打开网页 → 后台 → 输入本地口令 `0427`。
7. 在后台填写 Supabase Project URL 和 anon / publishable key，点击“保存 Supabase 配置”。
8. 让玩家重新开一局测试。数据会进入 `sessions_latest` 表。

## 数据看哪里

- 主要看：`sessions_latest`，一局一行，后台不卡。
- 可选看：`session_events`，只存 start / finish / 每 8 题采样，不再爆量。

## 为什么之前 session_events 为空

旧版需要你直接在 HTML 里手动写 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY`。如果打开页面时提示“Supabase 未配置”，前端不会发请求。新版可以在网页后台直接填写并保存。

## 平衡调整

- 健康负值改成“慢-慢-快”循环，减少随机局大面积猝死。
- 使命、人际负值略微收敛，保留代价但不至于过早锁死结局。
- 结局判定从纯高阈值改成“路线优先 + 数值特征 + 兜底分配”。
- 已用 5000 局随机模拟检查，普通/隐藏/归零大多数可自然出现；另用定向状态测试确认 27 个结局判定条件均可命中。
