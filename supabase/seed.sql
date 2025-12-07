-- ============================================
-- ZAP Database - Seed Data (Development)
-- ============================================
-- 仅用于本地开发测试，不要在生产环境运行
-- ============================================

-- 测试用户
insert into public.profiles (id, privy_user_id, email, display_name, embedded_wallet, reputation_score, total_trades, preferred_language)
values
  ('a1111111-1111-1111-1111-111111111111', 'did:privy:test-user-alice', 'alice@test.com', 'Alice', '0x1111111111111111111111111111111111111111', 85, 12, 'zh'),
  ('b2222222-2222-2222-2222-222222222222', 'did:privy:test-user-bob', 'bob@test.com', 'Bob', '0x2222222222222222222222222222222222222222', 92, 25, 'en'),
  ('c3333333-3333-3333-3333-333333333333', 'did:privy:test-user-charlie', 'charlie@test.com', 'Charlie', '0x3333333333333333333333333333333333333333', 78, 8, 'zh');

-- 测试商品
insert into public.listings (id, seller_id, title, title_en, description, description_en, category, price_usdc, images, delivery_method, status)
values
  (
    'aa111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    'ChatGPT Plus 账号 1个月',
    'ChatGPT Plus Account 1 Month',
    '全新 ChatGPT Plus 账号，有效期1个月，购买后立即发送账号密码。',
    'Brand new ChatGPT Plus account, valid for 1 month. Account credentials will be sent immediately after purchase.',
    'digital-goods',
    15.00,
    array['https://example.com/images/chatgpt-1.jpg'],
    'digital',
    'active'
  ),
  (
    'aa222222-2222-2222-2222-222222222222',
    'b2222222-2222-2222-2222-222222222222',
    'Steam 游戏激活码 - Elden Ring',
    'Steam Game Key - Elden Ring',
    '艾尔登法环 Steam 激活码，全球区可用，永久有效。',
    'Elden Ring Steam activation key, global region, permanently valid.',
    'gaming',
    35.00,
    array['https://example.com/images/elden-ring-1.jpg', 'https://example.com/images/elden-ring-2.jpg'],
    'digital',
    'active'
  ),
  (
    'aa333333-3333-3333-3333-333333333333',
    'a1111111-1111-1111-1111-111111111111',
    'Midjourney 会员共享 1个月',
    'Midjourney Membership Sharing 1 Month',
    'Midjourney 标准版会员共享，每日可生成 50 张图片。',
    'Midjourney Standard membership sharing, 50 images per day.',
    'digital-goods',
    8.50,
    array['https://example.com/images/mj-1.jpg'],
    'digital',
    'active'
  ),
  (
    'aa444444-4444-4444-4444-444444444444',
    'c3333333-3333-3333-3333-333333333333',
    'Discord Nitro 礼品码 1年',
    'Discord Nitro Gift Code 1 Year',
    'Discord Nitro 年费礼品码，支持全球兑换。',
    'Discord Nitro annual gift code, redeemable globally.',
    'digital-goods',
    80.00,
    array['https://example.com/images/nitro-1.jpg'],
    'digital',
    'active'
  ),
  (
    'aa555555-5555-5555-5555-555555555555',
    'b2222222-2222-2222-2222-222222222222',
    'NFT 白名单资格 - DeGods',
    'NFT Whitelist Spot - DeGods',
    'DeGods 新系列白名单资格，保证 mint 1 个。',
    'DeGods new series whitelist spot, guaranteed 1 mint.',
    'nft',
    120.00,
    array['https://example.com/images/degods-1.jpg'],
    'digital',
    'active'
  );

-- 测试会话
insert into public.conversations (id, listing_id, participant_a, participant_b, last_message_at)
values
  (
    'cc111111-1111-1111-1111-111111111111',
    'aa111111-1111-1111-1111-111111111111',
    'b2222222-2222-2222-2222-222222222222', -- Bob (买家)
    'a1111111-1111-1111-1111-111111111111', -- Alice (卖家)
    now() - interval '5 minutes'
  );

-- 测试消息
insert into public.messages (conversation_id, listing_id, sender_id, receiver_id, content, is_read, created_at)
values
  (
    'cc111111-1111-1111-1111-111111111111',
    'aa111111-1111-1111-1111-111111111111',
    'b2222222-2222-2222-2222-222222222222',
    'a1111111-1111-1111-1111-111111111111',
    'Hi! 这个 ChatGPT Plus 账号还在吗？',
    true,
    now() - interval '10 minutes'
  ),
  (
    'cc111111-1111-1111-1111-111111111111',
    'aa111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    'b2222222-2222-2222-2222-222222222222',
    '在的！随时可以下单，支付后秒发。',
    true,
    now() - interval '8 minutes'
  ),
  (
    'cc111111-1111-1111-1111-111111111111',
    'aa111111-1111-1111-1111-111111111111',
    'b2222222-2222-2222-2222-222222222222',
    'a1111111-1111-1111-1111-111111111111',
    '好的，我现在下单',
    false,
    now() - interval '5 minutes'
  );

-- 测试订单（已完成）
insert into public.orders (id, listing_id, buyer_id, seller_id, escrow_order_id, amount_usdc, buyer_fee_usdc, seller_fee_usdc, status, tx_hash, created_at)
values
  (
    'dd111111-1111-1111-1111-111111111111',
    'aa222222-2222-2222-2222-222222222222',
    'c3333333-3333-3333-3333-333333333333', -- Charlie 买
    'b2222222-2222-2222-2222-222222222222', -- Bob 卖
    1001,
    35.00,
    0.07,
    0.07,
    'completed',
    '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
    now() - interval '3 days'
  );

-- 测试评价
insert into public.reviews (order_id, reviewer_id, reviewee_id, rating, comment, created_at)
values
  (
    'dd111111-1111-1111-1111-111111111111',
    'c3333333-3333-3333-3333-333333333333', -- Charlie 评价 Bob
    'b2222222-2222-2222-2222-222222222222',
    5,
    '发货很快，激活码有效，非常满意！',
    now() - interval '2 days'
  ),
  (
    'dd111111-1111-1111-1111-111111111111',
    'b2222222-2222-2222-2222-222222222222', -- Bob 评价 Charlie
    'c3333333-3333-3333-3333-333333333333',
    5,
    '爽快的买家，秒确认收货，好评！',
    now() - interval '2 days'
  );

