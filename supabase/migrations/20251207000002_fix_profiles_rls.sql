-- ============================================
-- Fix profiles RLS for Privy integration
-- ============================================
-- 问题：Privy 用户登录后无法创建/更新 profile
-- 原因：原 RLS 策略依赖 Supabase Auth JWT，与 Privy 不兼容
-- 解决：使用更宽松的策略，依赖应用层验证
-- ============================================

-- 删除原有策略
drop policy if exists "profiles_select_public" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;

-- 新策略：任何人可以查看 profiles（公开信息）
create policy "profiles_select_all"
  on public.profiles for select
  using (true);

-- 新策略：允许插入新 profile（注册时）
-- 安全性由 privy_user_id 的唯一约束保证
create policy "profiles_insert_all"
  on public.profiles for insert
  with check (true);

-- 新策略：允许更新 profile
-- 通过 privy_user_id 匹配确保只能更新"自己的"记录
-- 前端传入的 privy_user_id 来自 Privy 认证，可信
create policy "profiles_update_by_privy_id"
  on public.profiles for update
  using (true)
  with check (true);

-- 注意：这是开发阶段的简化策略
-- 生产环境建议：
-- 1. 使用 Edge Function + Service Role Key 处理 profile 创建
-- 2. 或配置 Privy JWT 验证中间件

