-- ============================================
-- ZAP Database Schema - Initial Migration
-- ============================================
-- Web3 P2P Marketplace on Base Chain
-- ============================================

-- Enable extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ============================================
-- PROFILES (用户资料)
-- ============================================
create table public.profiles (
  id uuid primary key default uuid_generate_v4(),
  privy_user_id text unique not null,
  email text,
  display_name text,
  avatar_url text,
  embedded_wallet text,
  linked_wallets text[] default '{}',
  reputation_score int default 0,
  total_trades int default 0,
  preferred_language text default 'zh' check (preferred_language in ('zh', 'en')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

comment on table public.profiles is '用户资料表，关联 Privy 身份';
comment on column public.profiles.privy_user_id is 'Privy 用户唯一标识';
comment on column public.profiles.embedded_wallet is 'Privy 自动创建的嵌入式钱包地址';
comment on column public.profiles.linked_wallets is '用户绑定的外部钱包地址数组';
comment on column public.profiles.reputation_score is '信用分数，基于交易评价计算';

-- ============================================
-- LISTINGS (商品列表)
-- ============================================
create table public.listings (
  id uuid primary key default uuid_generate_v4(),
  seller_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  title_en text,
  description text,
  description_en text,
  category text not null,
  price_usdc numeric(18, 6) not null check (price_usdc > 0),
  images text[] default '{}',
  delivery_method text not null default 'digital' check (delivery_method in ('digital', 'physical')),
  delivery_info text,
  status text not null default 'pending_review' check (status in ('active', 'sold', 'hidden', 'pending_review', 'rejected')),
  escrow_order_id bigint,
  view_count int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

comment on table public.listings is '商品列表';
comment on column public.listings.price_usdc is '价格（USDC），精确到 6 位小数';
comment on column public.listings.escrow_order_id is '关联的链上托管订单 ID';
comment on column public.listings.status is '商品状态: active=上架, sold=已售, hidden=下架, pending_review=待审核, rejected=审核拒绝';

-- ============================================
-- ORDERS (订单)
-- ============================================
create table public.orders (
  id uuid primary key default uuid_generate_v4(),
  listing_id uuid not null references public.listings(id) on delete restrict,
  buyer_id uuid not null references public.profiles(id) on delete restrict,
  seller_id uuid not null references public.profiles(id) on delete restrict,
  escrow_order_id bigint unique,
  amount_usdc numeric(18, 6) not null,
  buyer_fee_usdc numeric(18, 6) not null default 0,
  seller_fee_usdc numeric(18, 6) not null default 0,
  status text not null default 'pending' check (status in ('pending', 'paid', 'delivered', 'completed', 'disputed', 'refunded', 'cancelled')),
  tx_hash text,
  delivery_tx_hash text,
  dispute_reason text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

comment on table public.orders is '订单表，关联链上 Escrow 合约';
comment on column public.orders.escrow_order_id is '链上托管合约的订单 ID';
comment on column public.orders.buyer_fee_usdc is '买家手续费 (0.2%)';
comment on column public.orders.seller_fee_usdc is '卖家手续费 (0.2%)';
comment on column public.orders.tx_hash is '支付交易哈希';
comment on column public.orders.status is '订单状态: pending=待支付, paid=已支付, delivered=已发货, completed=已完成, disputed=争议中, refunded=已退款, cancelled=已取消';

-- ============================================
-- CONVERSATIONS (会话)
-- ============================================
create table public.conversations (
  id uuid primary key default uuid_generate_v4(),
  listing_id uuid references public.listings(id) on delete set null,
  participant_a uuid not null references public.profiles(id) on delete cascade,
  participant_b uuid not null references public.profiles(id) on delete cascade,
  last_message_at timestamptz,
  created_at timestamptz default now(),
  
  -- 确保同一商品的两个用户只有一个会话
  unique (listing_id, participant_a, participant_b)
);

comment on table public.conversations is '聊天会话表';
comment on column public.conversations.listing_id is '关联的商品（可为空，用于通用对话）';

-- ============================================
-- MESSAGES (消息)
-- ============================================
create table public.messages (
  id uuid primary key default uuid_generate_v4(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete set null,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  is_read boolean default false,
  created_at timestamptz default now()
);

comment on table public.messages is '聊天消息表';

-- ============================================
-- REVIEWS (评价)
-- ============================================
create table public.reviews (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid not null references public.orders(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  reviewee_id uuid not null references public.profiles(id) on delete cascade,
  rating int not null check (rating >= 1 and rating <= 5),
  comment text,
  created_at timestamptz default now(),
  
  -- 每个订单每个用户只能评价一次
  unique (order_id, reviewer_id)
);

comment on table public.reviews is '交易评价表';
comment on column public.reviews.rating is '评分 1-5 星';

-- ============================================
-- UPDATED_AT 触发器函数
-- ============================================
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- 为需要的表添加触发器
create trigger set_updated_at
  before update on public.profiles
  for each row execute function public.handle_updated_at();

create trigger set_updated_at
  before update on public.listings
  for each row execute function public.handle_updated_at();

create trigger set_updated_at
  before update on public.orders
  for each row execute function public.handle_updated_at();

-- ============================================
-- 更新会话最后消息时间的触发器
-- ============================================
create or replace function public.update_conversation_last_message()
returns trigger as $$
begin
  update public.conversations
  set last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$ language plpgsql;

create trigger update_last_message_at
  after insert on public.messages
  for each row execute function public.update_conversation_last_message();

-- ============================================
-- 更新用户信用分的触发器
-- ============================================
create or replace function public.update_reputation_score()
returns trigger as $$
declare
  avg_rating numeric;
  trade_count int;
begin
  -- 计算被评价用户的平均评分
  select avg(rating), count(*)
  into avg_rating, trade_count
  from public.reviews
  where reviewee_id = new.reviewee_id;
  
  -- 更新用户资料
  update public.profiles
  set 
    reputation_score = coalesce(round(avg_rating * 20), 0), -- 转换为 0-100 分
    total_trades = trade_count
  where id = new.reviewee_id;
  
  return new;
end;
$$ language plpgsql;

create trigger update_user_reputation
  after insert on public.reviews
  for each row execute function public.update_reputation_score();

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- 启用 RLS
alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.orders enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.reviews enable row level security;

-- --------------------------------------------
-- 辅助函数：从 JWT 获取当前用户 ID
-- --------------------------------------------
create or replace function public.get_current_user_id()
returns uuid as $$
declare
  privy_id text;
  user_id uuid;
begin
  -- 从 JWT claims 中获取 Privy user ID
  privy_id := current_setting('request.jwt.claims', true)::json->>'sub';
  
  if privy_id is null then
    return null;
  end if;
  
  -- 查找对应的用户 ID
  select id into user_id
  from public.profiles
  where privy_user_id = privy_id;
  
  return user_id;
end;
$$ language plpgsql security definer;

-- --------------------------------------------
-- PROFILES 策略
-- --------------------------------------------
-- 所有人可以查看用户公开资料
create policy "profiles_select_public"
  on public.profiles for select
  using (true);

-- 用户可以更新自己的资料
create policy "profiles_update_own"
  on public.profiles for update
  using (id = public.get_current_user_id());

-- 用户可以插入自己的资料（注册时）
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (true); -- 由 Edge Function 控制

-- --------------------------------------------
-- LISTINGS 策略
-- --------------------------------------------
-- 任何人可以查看已上架商品
create policy "listings_select_active"
  on public.listings for select
  using (status = 'active' or seller_id = public.get_current_user_id());

-- 卖家可以创建商品
create policy "listings_insert_own"
  on public.listings for insert
  with check (seller_id = public.get_current_user_id());

-- 卖家可以更新自己的商品
create policy "listings_update_own"
  on public.listings for update
  using (seller_id = public.get_current_user_id());

-- 卖家可以删除自己的商品
create policy "listings_delete_own"
  on public.listings for delete
  using (seller_id = public.get_current_user_id());

-- --------------------------------------------
-- ORDERS 策略
-- --------------------------------------------
-- 买家和卖家可以查看自己的订单
create policy "orders_select_own"
  on public.orders for select
  using (
    buyer_id = public.get_current_user_id() or
    seller_id = public.get_current_user_id()
  );

-- 买家可以创建订单
create policy "orders_insert_buyer"
  on public.orders for insert
  with check (buyer_id = public.get_current_user_id());

-- 买家和卖家可以更新订单状态
create policy "orders_update_participant"
  on public.orders for update
  using (
    buyer_id = public.get_current_user_id() or
    seller_id = public.get_current_user_id()
  );

-- --------------------------------------------
-- CONVERSATIONS 策略
-- --------------------------------------------
-- 参与者可以查看自己的会话
create policy "conversations_select_participant"
  on public.conversations for select
  using (
    participant_a = public.get_current_user_id() or
    participant_b = public.get_current_user_id()
  );

-- 用户可以创建会话
create policy "conversations_insert_participant"
  on public.conversations for insert
  with check (
    participant_a = public.get_current_user_id() or
    participant_b = public.get_current_user_id()
  );

-- --------------------------------------------
-- MESSAGES 策略
-- --------------------------------------------
-- 参与者可以查看消息
create policy "messages_select_participant"
  on public.messages for select
  using (
    sender_id = public.get_current_user_id() or
    receiver_id = public.get_current_user_id()
  );

-- 发送者可以插入消息
create policy "messages_insert_sender"
  on public.messages for insert
  with check (sender_id = public.get_current_user_id());

-- 接收者可以更新消息（标记已读）
create policy "messages_update_receiver"
  on public.messages for update
  using (receiver_id = public.get_current_user_id());

-- --------------------------------------------
-- REVIEWS 策略
-- --------------------------------------------
-- 所有人可以查看评价
create policy "reviews_select_public"
  on public.reviews for select
  using (true);

-- 评价者可以创建评价
create policy "reviews_insert_reviewer"
  on public.reviews for insert
  with check (reviewer_id = public.get_current_user_id());

-- ============================================
-- STORAGE BUCKETS
-- ============================================

-- 创建商品图片 bucket
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'listing-images',
  'listing-images',
  true,
  5242880, -- 5MB
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
);

-- 创建用户头像 bucket
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2097152, -- 2MB
  array['image/jpeg', 'image/png', 'image/webp']
);

-- Storage 策略：listing-images
create policy "listing_images_select_public"
  on storage.objects for select
  using (bucket_id = 'listing-images');

create policy "listing_images_insert_authenticated"
  on storage.objects for insert
  with check (
    bucket_id = 'listing-images' and
    auth.role() = 'authenticated'
  );

create policy "listing_images_delete_own"
  on storage.objects for delete
  using (
    bucket_id = 'listing-images' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Storage 策略：avatars
create policy "avatars_select_public"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "avatars_insert_authenticated"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars' and
    auth.role() = 'authenticated'
  );

create policy "avatars_update_own"
  on storage.objects for update
  using (
    bucket_id = 'avatars' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "avatars_delete_own"
  on storage.objects for delete
  using (
    bucket_id = 'avatars' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

