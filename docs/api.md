# ZAP Server - API 文档

> Supabase API 与 Edge Functions 接口说明

---

## 📋 概述

ZAP 后端 API 分为两类：

1. **Supabase 自动生成的 REST API** - 数据 CRUD
2. **Edge Functions** - 自定义业务逻辑

---

## 🔐 认证方式

### Privy + Supabase 集成

```typescript
// 前端初始化
import { createClient } from '@supabase/supabase-js'
import { usePrivy } from '@privy-io/react-auth'

const supabase = createClient(
  process.env.VITE_SUPABASE_URL!,
  process.env.VITE_SUPABASE_ANON_KEY!
)

// 使用 Privy 获取的 token 设置 Supabase session
function useSupabaseWithPrivy() {
  const { getAccessToken } = usePrivy()
  
  useEffect(() => {
    const setSession = async () => {
      const token = await getAccessToken()
      if (token) {
        supabase.auth.setSession({
          access_token: token,
          refresh_token: '',
        })
      }
    }
    setSession()
  }, [])
  
  return supabase
}
```

---

## 📊 数据 API (自动生成)

### Profiles (用户)

#### 获取当前用户资料

```typescript
const { data, error } = await supabase
  .from('profiles')
  .select('*')
  .eq('id', userId)
  .single()
```

#### 更新用户资料

```typescript
const { error } = await supabase
  .from('profiles')
  .update({
    display_name: 'New Name',
    avatar_url: 'https://...',
  })
  .eq('id', userId)
```

#### 绑定外部钱包

```typescript
const { error } = await supabase
  .from('profiles')
  .update({
    linked_wallets: [...existingWallets, newWalletAddress],
  })
  .eq('id', userId)
```

---

### Listings (商品)

#### 获取商品列表

```typescript
// 分页获取
const { data, error, count } = await supabase
  .from('listings')
  .select('*, seller:profiles(*)', { count: 'exact' })
  .eq('status', 'active')
  .order('created_at', { ascending: false })
  .range(0, 19) // 每页 20 条
```

#### 按分类筛选

```typescript
const { data } = await supabase
  .from('listings')
  .select('*, seller:profiles(*)')
  .eq('status', 'active')
  .eq('category', '游戏账号')
  .order('created_at', { ascending: false })
```

#### 搜索商品

```typescript
const { data } = await supabase
  .from('listings')
  .select('*, seller:profiles(*)')
  .eq('status', 'active')
  .or(`title.ilike.%${keyword}%,description.ilike.%${keyword}%`)
```

#### 获取商品详情

```typescript
const { data } = await supabase
  .from('listings')
  .select(`
    *,
    seller:profiles(*)
  `)
  .eq('id', listingId)
  .single()
```

#### 发布商品

```typescript
const { data, error } = await supabase
  .from('listings')
  .insert({
    seller_id: userId,
    title: '游戏账号',
    description: '...',
    category: '游戏账号',
    price_usdc: 50,
    images: ['https://...'],
    delivery_method: 'digital',
    delivery_info: '购买后私信发送账号密码',
  })
  .select()
  .single()
```

#### 更新商品

```typescript
const { error } = await supabase
  .from('listings')
  .update({
    title: 'Updated Title',
    price_usdc: 60,
  })
  .eq('id', listingId)
  .eq('seller_id', userId) // RLS 保护
```

#### 下架商品

```typescript
const { error } = await supabase
  .from('listings')
  .update({ status: 'hidden' })
  .eq('id', listingId)
```

---

### Orders (订单)

#### 创建订单

```typescript
const { data, error } = await supabase
  .from('orders')
  .insert({
    listing_id: listingId,
    buyer_id: buyerId,
    seller_id: sellerId,
    escrow_order_id: onchainOrderId, // 链上订单 ID
    amount_usdc: 100,
    buyer_fee_usdc: 0.2,
    seller_fee_usdc: 0.2,
    status: 'pending',
  })
  .select()
  .single()
```

#### 获取用户订单列表

```typescript
// 买家订单
const { data: buyerOrders } = await supabase
  .from('orders')
  .select(`
    *,
    listing:listings(*),
    seller:profiles!seller_id(*)
  `)
  .eq('buyer_id', userId)
  .order('created_at', { ascending: false })

// 卖家订单
const { data: sellerOrders } = await supabase
  .from('orders')
  .select(`
    *,
    listing:listings(*),
    buyer:profiles!buyer_id(*)
  `)
  .eq('seller_id', userId)
  .order('created_at', { ascending: false })
```

#### 更新订单状态

```typescript
const { error } = await supabase
  .from('orders')
  .update({
    status: 'paid',
    tx_hash: transactionHash,
  })
  .eq('id', orderId)
```

---

### Messages (消息)

#### 获取会话列表

```typescript
const { data } = await supabase
  .from('conversations')
  .select(`
    *,
    listing:listings(id, title, images),
    other_user:profiles!participant_b(id, display_name, avatar_url)
  `)
  .or(`participant_a.eq.${userId},participant_b.eq.${userId}`)
  .order('last_message_at', { ascending: false })
```

#### 获取会话消息

```typescript
const { data } = await supabase
  .from('messages')
  .select('*')
  .eq('conversation_id', conversationId)
  .order('created_at', { ascending: true })
```

#### 发送消息

```typescript
const { error } = await supabase.from('messages').insert({
  conversation_id: conversationId,
  listing_id: listingId,
  sender_id: userId,
  receiver_id: otherUserId,
  content: messageText,
})

// 更新会话最后消息时间
await supabase
  .from('conversations')
  .update({ last_message_at: new Date().toISOString() })
  .eq('id', conversationId)
```

#### 标记消息已读

```typescript
const { error } = await supabase
  .from('messages')
  .update({ is_read: true })
  .eq('conversation_id', conversationId)
  .eq('receiver_id', userId)
  .eq('is_read', false)
```

---

### Reviews (评价)

#### 提交评价

```typescript
const { error } = await supabase.from('reviews').insert({
  order_id: orderId,
  reviewer_id: userId,
  reviewee_id: otherUserId,
  rating: 5,
  comment: '发货很快，商品完美！',
})

// 更新被评价者的信誉分
await supabase.rpc('update_reputation', { user_id: otherUserId })
```

#### 获取用户评价

```typescript
const { data } = await supabase
  .from('reviews')
  .select(`
    *,
    reviewer:profiles!reviewer_id(display_name, avatar_url)
  `)
  .eq('reviewee_id', userId)
  .order('created_at', { ascending: false })
```

---

## ⚡ Edge Functions API

### 1. 内容审核

**Endpoint**: `POST /functions/v1/moderate-content`

**请求**

```typescript
const response = await fetch(
  `${SUPABASE_URL}/functions/v1/moderate-content`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      title: '商品标题',
      description: '商品描述',
      images: ['https://...'], // 可选，图片审核
    }),
  }
)

const result = await response.json()
```

**响应**

```json
// 通过
{
  "passed": true,
  "categories": null
}

// 不通过
{
  "passed": false,
  "categories": {
    "sexual": true,
    "violence": false,
    "hate": false,
    "self-harm": false,
    "illegal": true
  },
  "message": "内容违规：包含色情或违法内容"
}
```

---

### 2. 发送邮件

**Endpoint**: `POST /functions/v1/send-email`

**请求**

```typescript
const response = await fetch(`${SUPABASE_URL}/functions/v1/send-email`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${SERVICE_ROLE_KEY}`, // 服务端调用
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    to: 'user@example.com',
    subject: '您有新订单',
    template: 'order_paid',
    data: {
      listingTitle: '游戏账号',
      amount: '100',
      orderUrl: 'https://zap.trade/orders/xxx',
    },
  }),
})
```

**模板类型**

| template | 触发场景 | 收件人 |
|----------|----------|--------|
| `order_created` | 买家下单 | 卖家 |
| `order_paid` | 买家付款 | 卖家 |
| `order_delivered` | 卖家发货 | 买家 |
| `order_completed` | 交易完成 | 双方 |
| `dispute_raised` | 发起纠纷 | 双方+管理员 |
| `timeout_warning` | 超时提醒 | 买家 |

---

### 3. 链上事件同步

**Endpoint**: `POST /functions/v1/sync-chain-events`

由链上事件监听服务调用（Envio/Ponder/自建），前端不直接调用。

**请求**

```typescript
const response = await fetch(
  `${SUPABASE_URL}/functions/v1/sync-chain-events`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${WEBHOOK_SECRET}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      eventName: 'OrderPaid',
      transactionHash: '0x...',
      blockNumber: 12345678,
      args: {
        orderId: 1,
        buyer: '0x...',
        totalPaid: '100200000', // 6位小数
      },
    }),
  }
)
```

---

## 🖼️ Storage API

### 上传图片

```typescript
const file = event.target.files[0]
const fileName = `${userId}/${Date.now()}-${file.name}`

const { data, error } = await supabase.storage
  .from('listing-images')
  .upload(fileName, file, {
    cacheControl: '3600',
    upsert: false,
  })

// 获取公开 URL
const { data: { publicUrl } } = supabase.storage
  .from('listing-images')
  .getPublicUrl(fileName)
```

### 删除图片

```typescript
const { error } = await supabase.storage
  .from('listing-images')
  .remove([fileName])
```

### 图片变换（缩略图）

```typescript
// 获取 200x200 缩略图
const { data: { publicUrl } } = supabase.storage
  .from('listing-images')
  .getPublicUrl(fileName, {
    transform: {
      width: 200,
      height: 200,
      resize: 'cover',
    },
  })
```

---

## 🔄 Realtime 订阅

### 订阅新消息

```typescript
const channel = supabase
  .channel('messages')
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'messages',
      filter: `receiver_id=eq.${userId}`,
    },
    (payload) => {
      console.log('New message:', payload.new)
      // 显示通知、播放声音等
    }
  )
  .subscribe()
```

### 订阅订单状态变化

```typescript
const channel = supabase
  .channel('orders')
  .on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'orders',
      filter: `buyer_id=eq.${userId}`,
    },
    (payload) => {
      if (payload.new.status !== payload.old.status) {
        console.log('Order status changed:', payload.new.status)
      }
    }
  )
  .subscribe()
```

---

## 🛠️ 数据库函数 (RPC)

### 更新信誉分

```sql
-- supabase/migrations/xxx_add_functions.sql
create or replace function update_reputation(target_user_id uuid)
returns void as $$
declare
  avg_rating numeric;
  trade_count int;
begin
  select avg(rating), count(*)
  into avg_rating, trade_count
  from reviews
  where reviewee_id = target_user_id;
  
  update profiles
  set 
    reputation_score = coalesce(round(avg_rating * 20), 0), -- 5星制转100分制
    total_trades = trade_count
  where id = target_user_id;
end;
$$ language plpgsql security definer;
```

**调用**

```typescript
await supabase.rpc('update_reputation', { target_user_id: userId })
```

### 获取商品统计

```sql
create or replace function get_listing_stats(listing_id uuid)
returns json as $$
select json_build_object(
  'view_count', l.view_count,
  'message_count', (select count(*) from messages where listing_id = l.id),
  'order_count', (select count(*) from orders where listing_id = l.id)
)
from listings l
where l.id = listing_id;
$$ language sql stable;
```

---

## 📝 错误处理

### 常见错误码

| 错误码 | 说明 | 处理方式 |
|--------|------|----------|
| `PGRST116` | 未找到记录 | 显示"商品不存在" |
| `PGRST301` | 权限不足 | 检查用户登录状态 |
| `23505` | 唯一约束冲突 | 提示重复操作 |
| `23503` | 外键约束失败 | 检查关联数据 |

### 统一错误处理

```typescript
async function supabaseQuery<T>(
  query: Promise<{ data: T | null; error: Error | null }>
): Promise<T> {
  const { data, error } = await query
  
  if (error) {
    console.error('Supabase error:', error)
    
    if (error.code === 'PGRST116') {
      throw new Error('记录不存在')
    }
    if (error.code === 'PGRST301') {
      throw new Error('权限不足，请重新登录')
    }
    
    throw new Error(error.message)
  }
  
  return data as T
}

// 使用
const listing = await supabaseQuery(
  supabase.from('listings').select('*').eq('id', id).single()
)
```

