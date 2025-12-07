# ZAP Server - 后端架构

> Supabase 后端技术文档

---

## 📋 概述

ZAP 后端采用 **Supabase** 全家桶，最大限度减少后端开发工作量：

- **PostgreSQL** - 数据存储
- **Auth** - 与 Privy 配合的用户认证
- **Storage** - 商品图片存储
- **Realtime** - 即时聊天
- **Edge Functions** - 内容审核、邮件通知、链上事件同步

---

## 🏗️ 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    Supabase 项目                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 PostgreSQL                          │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐            │   │
│  │  │ profiles │ │ listings │ │ orders   │            │   │
│  │  └──────────┘ └──────────┘ └──────────┘            │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐            │   │
│  │  │ messages │ │ conversations │ │ reviews │        │   │
│  │  └──────────┘ └──────────┘ └──────────┘            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 Storage Buckets                     │   │
│  │  ┌──────────────────┐ ┌──────────────────┐          │   │
│  │  │ listing-images   │ │ avatars          │          │   │
│  │  │ (商品图片)       │ │ (用户头像)        │          │   │
│  │  └──────────────────┘ └──────────────────┘          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 Realtime                            │   │
│  │  - 聊天消息订阅                                     │   │
│  │  - 订单状态变更通知                                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 Edge Functions                      │   │
│  │  ┌────────────────┐ ┌────────────────┐              │   │
│  │  │ moderate-      │ │ send-email     │              │   │
│  │  │ content        │ │ (Resend)       │              │   │
│  │  └────────────────┘ └────────────────┘              │   │
│  │  ┌────────────────┐ ┌────────────────┐              │   │
│  │  │ sync-chain-    │ │ verify-wallet  │              │   │
│  │  │ events         │ │ -signature     │              │   │
│  │  └────────────────┘ └────────────────┘              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🗄️ 数据库设计

### 表结构

```
profiles (用户)
├── id: uuid (PK)
├── privy_user_id: text (唯一)
├── email: text
├── display_name: text
├── avatar_url: text
├── embedded_wallet: text
├── linked_wallets: text[]
├── reputation_score: int
├── total_trades: int
├── preferred_language: text (zh/en)
├── created_at: timestamptz
└── updated_at: timestamptz

listings (商品)
├── id: uuid (PK)
├── seller_id: uuid (FK → profiles)
├── title: text
├── title_en: text
├── description: text
├── description_en: text
├── category: text
├── price_usdc: numeric
├── images: text[]
├── delivery_method: text (digital/physical)
├── delivery_info: text
├── status: text (active/sold/hidden/pending_review)
├── escrow_order_id: int
├── view_count: int
├── created_at: timestamptz
└── updated_at: timestamptz

orders (订单)
├── id: uuid (PK)
├── listing_id: uuid (FK → listings)
├── buyer_id: uuid (FK → profiles)
├── seller_id: uuid (FK → profiles)
├── escrow_order_id: int (链上订单ID)
├── amount_usdc: numeric
├── buyer_fee_usdc: numeric
├── seller_fee_usdc: numeric
├── status: text (pending/paid/delivered/completed/disputed/refunded)
├── tx_hash: text
├── delivery_tx_hash: text
├── dispute_reason: text
├── created_at: timestamptz
└── updated_at: timestamptz

conversations (会话)
├── id: uuid (PK)
├── listing_id: uuid (FK → listings)
├── participant_a: uuid (FK → profiles)
├── participant_b: uuid (FK → profiles)
├── last_message_at: timestamptz
└── created_at: timestamptz

messages (消息)
├── id: uuid (PK)
├── conversation_id: uuid (FK → conversations)
├── listing_id: uuid (FK → listings)
├── sender_id: uuid (FK → profiles)
├── receiver_id: uuid (FK → profiles)
├── content: text
├── is_read: boolean
└── created_at: timestamptz

reviews (评价)
├── id: uuid (PK)
├── order_id: uuid (FK → orders)
├── reviewer_id: uuid (FK → profiles)
├── reviewee_id: uuid (FK → profiles)
├── rating: int (1-5)
├── comment: text
└── created_at: timestamptz
```

### 关系图

```
profiles ◄───┬─── listings (seller_id)
             │
             ├─── orders (buyer_id, seller_id)
             │
             ├─── messages (sender_id, receiver_id)
             │
             ├─── conversations (participant_a, participant_b)
             │
             └─── reviews (reviewer_id, reviewee_id)

listings ◄───┬─── orders (listing_id)
             │
             ├─── messages (listing_id)
             │
             └─── conversations (listing_id)

orders ◄───── reviews (order_id)

conversations ◄─── messages (conversation_id)
```

---

## 🔐 Row Level Security (RLS)

### profiles

```sql
-- 用户只能查看和编辑自己的资料
create policy "Users can view own profile"
  on profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on profiles for update
  using (auth.uid() = id);

-- 公开信息（其他用户可见）
create policy "Public profiles are viewable"
  on profiles for select
  using (true);
```

### listings

```sql
-- 任何人可以查看上架商品
create policy "Active listings are viewable"
  on listings for select
  using (status = 'active');

-- 卖家可以管理自己的商品
create policy "Sellers can manage own listings"
  on listings for all
  using (auth.uid() = seller_id);
```

### messages

```sql
-- 只有对话参与者可以查看消息
create policy "Participants can view messages"
  on messages for select
  using (
    auth.uid() = sender_id or
    auth.uid() = receiver_id
  );

-- 用户只能发送自己的消息
create policy "Users can send messages"
  on messages for insert
  with check (auth.uid() = sender_id);
```

---

## 📦 Storage Buckets

### listing-images

```sql
-- 创建 bucket
insert into storage.buckets (id, name, public)
values ('listing-images', 'listing-images', true);

-- 上传策略：登录用户可上传
create policy "Authenticated users can upload"
  on storage.objects for insert
  with check (
    bucket_id = 'listing-images' and
    auth.role() = 'authenticated'
  );

-- 读取策略：公开可读
create policy "Public read access"
  on storage.objects for select
  using (bucket_id = 'listing-images');
```

### 图片优化

- 最大尺寸：5MB
- 支持格式：jpg, png, webp, gif
- 自动生成缩略图（Supabase Image Transformation）

---

## ⚡ Edge Functions

### 1. moderate-content

内容审核函数，发布商品时调用。

```typescript
// supabase/functions/moderate-content/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import OpenAI from 'https://deno.land/x/openai@v4.20.1/mod.ts'

serve(async (req) => {
  const { title, description, images } = await req.json()
  
  const openai = new OpenAI({
    apiKey: Deno.env.get('OPENAI_API_KEY'),
  })
  
  // 文本审核
  const moderation = await openai.moderations.create({
    input: `${title}\n${description}`,
  })
  
  const flagged = moderation.results[0].flagged
  const categories = moderation.results[0].categories
  
  return new Response(
    JSON.stringify({
      passed: !flagged,
      categories: flagged ? categories : null,
    }),
    { headers: { 'Content-Type': 'application/json' } }
  )
})
```

### 2. send-email

邮件通知函数。

```typescript
// supabase/functions/send-email/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { Resend } from 'https://esm.sh/resend@2.0.0'

const resend = new Resend(Deno.env.get('RESEND_API_KEY'))

serve(async (req) => {
  const { to, subject, template, data } = await req.json()
  
  const templates = {
    order_created: (data) => `
      <h1>您有新订单！</h1>
      <p>商品：${data.listingTitle}</p>
      <p>金额：${data.amount} USDC</p>
      <a href="${data.orderUrl}">查看订单</a>
    `,
    order_paid: (data) => `
      <h1>订单已支付</h1>
      <p>买家已付款，请尽快发货。</p>
      <a href="${data.orderUrl}">处理订单</a>
    `,
    order_completed: (data) => `
      <h1>交易完成</h1>
      <p>恭喜！交易已完成。</p>
      <p>您收到：${data.amount} USDC</p>
    `,
  }
  
  await resend.emails.send({
    from: 'ZAP <noreply@zap.trade>',
    to,
    subject,
    html: templates[template](data),
  })
  
  return new Response(JSON.stringify({ success: true }))
})
```

### 3. sync-chain-events

链上事件同步（可选，也可用 Envio/Ponder）。

```typescript
// supabase/functions/sync-chain-events/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const event = await req.json() // 来自链上事件监听
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  
  switch (event.eventName) {
    case 'OrderPaid':
      await supabase
        .from('orders')
        .update({
          status: 'paid',
          tx_hash: event.transactionHash,
        })
        .eq('escrow_order_id', event.args.orderId)
      
      // 发送邮件通知卖家
      await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-email`, {
        method: 'POST',
        body: JSON.stringify({
          to: event.sellerEmail,
          subject: '您有新订单！',
          template: 'order_paid',
          data: { orderUrl: `https://zap.trade/orders/${event.args.orderId}` }
        })
      })
      break
      
    case 'OrderCompleted':
      await supabase
        .from('orders')
        .update({ status: 'completed' })
        .eq('escrow_order_id', event.args.orderId)
      break
  }
  
  return new Response(JSON.stringify({ success: true }))
})
```

---

## 🔄 Realtime 配置

### 聊天消息订阅

```typescript
// 前端代码
import { useEffect } from 'react'
import { supabase } from '@/lib/supabase'

function useMessages(conversationId: string) {
  const [messages, setMessages] = useState([])
  
  useEffect(() => {
    // 初始加载
    supabase
      .from('messages')
      .select('*')
      .eq('conversation_id', conversationId)
      .order('created_at')
      .then(({ data }) => setMessages(data || []))
    
    // 实时订阅
    const channel = supabase
      .channel(`messages:${conversationId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'messages',
          filter: `conversation_id=eq.${conversationId}`,
        },
        (payload) => {
          setMessages((prev) => [...prev, payload.new])
        }
      )
      .subscribe()
    
    return () => {
      supabase.removeChannel(channel)
    }
  }, [conversationId])
  
  return messages
}
```

---

## 📁 文件结构

```
zap-server/
├── supabase/
│   ├── migrations/
│   │   ├── 20251207000000_init.sql      # ✅ 表结构 + RLS + Storage + 触发器
│   │   └── 20251207000001_add_indexes.sql # ✅ 性能索引
│   ├── functions/                        # 🚧 待开发
│   │   ├── moderate-content/
│   │   │   └── index.ts
│   │   ├── send-email/
│   │   │   └── index.ts
│   │   └── sync-chain-events/
│   │       └── index.ts
│   ├── seed.sql                          # ✅ 测试数据
│   └── config.toml                       # ✅ 本地配置
├── docs/
│   ├── architecture.md  (本文件)
│   └── api.md
├── .gitignore
└── README.md
```

---

## 🚀 部署流程

```bash
# 1. 登录 Supabase CLI
supabase login

# 2. 链接远程项目
supabase link --project-ref YOUR_PROJECT_REF

# 3. 推送数据库迁移
supabase db push

# 4. 部署 Edge Functions
supabase functions deploy moderate-content
supabase functions deploy send-email
supabase functions deploy sync-chain-events

# 5. 设置环境变量
supabase secrets set OPENAI_API_KEY=xxx
supabase secrets set RESEND_API_KEY=xxx
```

