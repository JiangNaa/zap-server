# ZAP Server

> 🗄️ ZAP 后端服务 - Supabase 全家桶

---

## 📋 概述

ZAP Server 采用 **Supabase** 构建，包含：

- **PostgreSQL** - 数据存储
- **Storage** - 图片存储
- **Realtime** - 即时聊天
- **Edge Functions** - 业务逻辑

---

## 🛠️ 技术栈

- **Supabase** (BaaS)
- **PostgreSQL** (数据库)
- **Deno** (Edge Functions)
- **Resend** (邮件服务)
- **OpenAI** (内容审核)

---

## 📁 项目结构

```
zap-server/
├── supabase/
│   ├── migrations/
│   │   └── 20240101000000_init.sql
│   ├── functions/
│   │   ├── moderate-content/
│   │   │   └── index.ts
│   │   ├── send-email/
│   │   │   └── index.ts
│   │   └── sync-chain-events/
│   │       └── index.ts
│   ├── seed.sql
│   └── config.toml
├── docs/
│   ├── architecture.md
│   └── api.md
└── README.md
```

---

## 🚀 快速开始

### 1. 安装 Supabase CLI

```bash
# macOS
brew install supabase/tap/supabase

# npm
npm install -g supabase
```

### 2. 本地开发

```bash
# 启动本地 Supabase
supabase start

# 查看状态
supabase status
```

### 3. 链接远程项目

```bash
# 登录
supabase login

# 链接项目
supabase link --project-ref YOUR_PROJECT_REF
```

### 4. 数据库迁移

```bash
# 推送迁移到远程
supabase db push

# 拉取远程 schema
supabase db pull
```

### 5. 部署 Edge Functions

```bash
# 部署所有函数
supabase functions deploy

# 部署单个函数
supabase functions deploy moderate-content
```

---

## ⚙️ 环境变量

### Supabase Dashboard 配置

在 Supabase Dashboard → Settings → Edge Functions → Secrets：

```
OPENAI_API_KEY=sk-xxx
RESEND_API_KEY=re_xxx
WEBHOOK_SECRET=your_secret
```

### 前端需要的变量

```bash
VITE_SUPABASE_URL=https://xxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJxxx
```

---

## 🔧 本地测试 Edge Functions

```bash
# 启动本地函数服务
supabase functions serve

# 调用测试
curl -X POST http://localhost:54321/functions/v1/moderate-content \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title": "测试商品", "description": "描述"}'
```

---

## 📖 文档

- [架构文档](./docs/architecture.md)
- [API 文档](./docs/api.md)

---

## 🔗 相关链接

- [Supabase Dashboard](https://supabase.com/dashboard)
- [Supabase 文档](https://supabase.com/docs)

---

## 📄 License

MIT

