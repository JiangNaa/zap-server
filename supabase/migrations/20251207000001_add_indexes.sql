-- ============================================
-- ZAP Database Schema - Performance Indexes
-- ============================================

-- ============================================
-- PROFILES 索引
-- ============================================
-- Privy ID 查找（登录时使用）
create index idx_profiles_privy_user_id on public.profiles(privy_user_id);

-- 钱包地址查找
create index idx_profiles_embedded_wallet on public.profiles(embedded_wallet);

-- 信用分排序
create index idx_profiles_reputation_score on public.profiles(reputation_score desc);

-- ============================================
-- LISTINGS 索引
-- ============================================
-- 卖家商品列表
create index idx_listings_seller_id on public.listings(seller_id);

-- 商品状态筛选
create index idx_listings_status on public.listings(status);

-- 分类筛选
create index idx_listings_category on public.listings(category);

-- 最新商品排序
create index idx_listings_created_at on public.listings(created_at desc);

-- 价格范围筛选
create index idx_listings_price_usdc on public.listings(price_usdc);

-- 复合索引：状态 + 创建时间（首页商品列表）
create index idx_listings_status_created on public.listings(status, created_at desc);

-- 复合索引：分类 + 状态 + 创建时间（分类页）
create index idx_listings_category_status_created on public.listings(category, status, created_at desc);

-- 链上订单 ID 查找
create index idx_listings_escrow_order_id on public.listings(escrow_order_id) where escrow_order_id is not null;

-- ============================================
-- ORDERS 索引
-- ============================================
-- 买家订单列表
create index idx_orders_buyer_id on public.orders(buyer_id);

-- 卖家订单列表
create index idx_orders_seller_id on public.orders(seller_id);

-- 订单状态筛选
create index idx_orders_status on public.orders(status);

-- 链上订单 ID 查找（事件同步）
create index idx_orders_escrow_order_id on public.orders(escrow_order_id) where escrow_order_id is not null;

-- 商品订单关联
create index idx_orders_listing_id on public.orders(listing_id);

-- 最新订单排序
create index idx_orders_created_at on public.orders(created_at desc);

-- 复合索引：买家 + 状态（买家订单页筛选）
create index idx_orders_buyer_status on public.orders(buyer_id, status);

-- 复合索引：卖家 + 状态（卖家订单页筛选）
create index idx_orders_seller_status on public.orders(seller_id, status);

-- ============================================
-- CONVERSATIONS 索引
-- ============================================
-- 参与者 A 的会话列表
create index idx_conversations_participant_a on public.conversations(participant_a);

-- 参与者 B 的会话列表
create index idx_conversations_participant_b on public.conversations(participant_b);

-- 商品相关会话
create index idx_conversations_listing_id on public.conversations(listing_id);

-- 最新消息排序
create index idx_conversations_last_message on public.conversations(last_message_at desc nulls last);

-- ============================================
-- MESSAGES 索引
-- ============================================
-- 会话消息列表
create index idx_messages_conversation_id on public.messages(conversation_id);

-- 消息时间排序
create index idx_messages_created_at on public.messages(created_at);

-- 发送者消息
create index idx_messages_sender_id on public.messages(sender_id);

-- 接收者消息
create index idx_messages_receiver_id on public.messages(receiver_id);

-- 未读消息查询
create index idx_messages_unread on public.messages(receiver_id, is_read) where is_read = false;

-- 复合索引：会话 + 时间（聊天记录加载）
create index idx_messages_conversation_created on public.messages(conversation_id, created_at);

-- ============================================
-- REVIEWS 索引
-- ============================================
-- 订单评价查询
create index idx_reviews_order_id on public.reviews(order_id);

-- 评价者查询
create index idx_reviews_reviewer_id on public.reviews(reviewer_id);

-- 被评价者查询（信用分计算）
create index idx_reviews_reviewee_id on public.reviews(reviewee_id);

-- 评分筛选
create index idx_reviews_rating on public.reviews(rating);

-- 最新评价排序
create index idx_reviews_created_at on public.reviews(created_at desc);

-- ============================================
-- 全文搜索索引（可选，后期优化）
-- ============================================
-- 商品标题和描述搜索
-- create index idx_listings_search on public.listings 
--   using gin(to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(description, '')));

