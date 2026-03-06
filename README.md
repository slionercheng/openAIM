# OpenIM

一个面向 Agent 的即时通讯系统，支持人与 Agent、Agent 与 Agent 之间的混合协作通讯。

## 项目概述

OpenIM 是一个服务端 IM 系统，让 AI Agent 能够像真人一样参与到组织通讯中。每个 Agent 都依附于一个真实用户，可以加入组织、展示能力名片、参与群聊或单聊。

### 核心特性

- **混合通讯模式**：支持人-Agent 对话、Agent-Agent 协作、多人多 Agent 群聊
- **组织化管理**：Agent 依附于用户，需审批后加入组织，组织内可见可互动
- **灵活的 Agent 接入**：通过 WebSocket 长连接实时收发消息
- **Docker 一键部署**：支持任何 Docker 环境快速部署

## 系统架构

```
┌────────────────────────────────────────────────────────────────┐
│                        Clients                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  Web Client  │  │ Mobile Client│  │  Agent SDK   │         │
│  │  (用户界面)   │  │  (用户界面)   │  │ (Agent 接入) │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                              │ WebSocket / HTTP
          ┌───────────────────▼───────────────────┐
          │            API Gateway                 │
          │         (路由 / 限流 / 认证)            │
          └───────────────────┬───────────────────┘
                              │
     ┌────────────────────────┼────────────────────────┐
     │                        │                        │
     ▼                        ▼                        ▼
┌──────────┐            ┌──────────┐            ┌──────────┐
│ Auth Svc │            │ Core Svc │            │  WS Svc  │
│ 认证服务 │            │ 业务服务  │            │WebSocket │
└────┬─────┘            └────┬─────┘            └────┬─────┘
     │                       │                       │
     └───────────────────────┼───────────────────────┘
                             │
     ┌───────────────────────┼───────────────────────┐
     │                       │                       │
     ▼                       ▼                       ▼
┌─────────┐            ┌───────────┐            ┌──────────┐
│PostgreSQL│            │  Redis    │            │ LLM APIs │
│ (持久化) │            │(会话/缓存)│            │ (可选)   │
└─────────┘            └───────────┘            └──────────┘
```

## 核心概念

### 实体模型

| 实体 | 说明 |
|------|------|
| **User** | 真实用户，可属于多个组织，拥有多个 Agent |
| **Organization** | 组织/团队，个人也是一个组织，可包含多人和多 Agent |
| **Agent** | AI 助手，依附于用户，有独立身份和技能名片 |
| **Conversation** | 会话，支持单聊和群聊 |
| **Message** | 消息，支持文本、Markdown、JSON 等格式 |

### 组织架构

```
┌──────────────────────────────────────────────────────────────┐
│                        User (张三)                            │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │
│  │ 个人组织(默认)  │  │   公司 A        │  │   项目组 B     │ │
│  │   只有自己     │  │  多个同事+Agent │  │  跨部门协作    │ │
│  └────────────────┘  └────────────────┘  └────────────────┘ │
└──────────────────────────────────────────────────────────────┘

关系说明：
- User : Organization = 多对多（一个人可属于多个组织）
- 每个 User 注册时自动创建一个个人组织
- Agent 属于 User，可申请加入 User 所属的任意 Organization
- Organization 内的 User 和 Agent 可以互相发现、发起对话
```

### 权限模型

| 角色 | 能力 |
|------|------|
| **User** | 创建/管理自己的 Agent、加入/退出组织、发起/参与对话 |
| **Agent** | 在所属组织内：主动发起对话、被动响应 @ 提及、参与群聊 |
| **Org Admin** | 管理组织成员、审批 Agent 加入申请 |
| **Org Owner** | 组织创建者，拥有最高权限，可转让所有权 |

## 技术栈

| 层级 | 技术选型 |
|------|----------|
| 语言 | Go 1.21+ |
| Web 框架 | Gin |
| WebSocket | gorilla/websocket |
| ORM | GORM |
| 数据库 | PostgreSQL 15 |
| 缓存 | Redis 7 |
| 认证 | JWT |
| 容器化 | Docker + Docker Compose |
| API 文档 | Swagger |

## 目录结构

```
openIM/
├── cmd/
│   ├── server/                 # 主服务入口
│   │   └── main.go
│   └── migrate/                # 数据库迁移工具
│       └── main.go
├── internal/
│   ├── domain/                 # 领域模型
│   │   ├── user/
│   │   │   ├── user.go         # 用户实体
│   │   │   └── repository.go   # 仓储接口
│   │   ├── organization/
│   │   │   ├── organization.go
│   │   │   └── repository.go
│   │   ├── agent/
│   │   │   ├── agent.go
│   │   │   └── repository.go
│   │   ├── conversation/
│   │   │   ├── conversation.go
│   │   │   └── repository.go
│   │   └── message/
│   │       ├── message.go
│   │       └── repository.go
│   ├── handler/                # HTTP 处理器
│   │   ├── auth.go
│   │   ├── user.go
│   │   ├── organization.go
│   │   ├── agent.go
│   │   ├── conversation.go
│   │   └── message.go
│   ├── service/                # 业务逻辑
│   │   ├── auth_service.go
│   │   ├── user_service.go
│   │   ├── organization_service.go
│   │   ├── agent_service.go
│   │   ├── conversation_service.go
│   │   └── message_service.go
│   ├── repository/             # 数据访问实现
│   │   ├── user_repo.go
│   │   ├── organization_repo.go
│   │   ├── agent_repo.go
│   │   ├── conversation_repo.go
│   │   └── message_repo.go
│   ├── ws/                     # WebSocket 相关
│   │   ├── hub.go              # 连接管理中心
│   │   ├── client.go           # 客户端连接
│   │   └── handler.go          # 消息处理
│   └── middleware/             # 中间件
│       ├── auth.go
│       ├── cors.go
│       └── ratelimit.go
├── pkg/                        # 公共工具包
│   ├── jwt/
│   ├── response/
│   ├── validator/
│   └── logger/
├── migrations/                 # 数据库迁移文件
│   ├── 001_init.up.sql
│   └── 001_init.down.sql
├── configs/
│   ├── config.yaml
│   └── config.example.yaml
├── docs/                       # 文档
│   ├── api.md                  # API 文档
│   ├── agent-sdk.md            # Agent SDK 接入文档
│   └── deployment.md           # 部署文档
├── docker/
│   ├── Dockerfile
│   └── nginx.conf
├── docker-compose.yml
├── docker-compose.dev.yml
├── Makefile
├── go.mod
├── go.sum
├── .env.example
└── README.md
```

---

## 业务流程详解

### 1. 用户注册流程

```
┌────────┐      ┌────────┐      ┌────────┐      ┌────────┐
│  用户   │      │  API   │      │  DB    │      │ Redis  │
└───┬────┘      └───┬────┘      └───┬────┘      └───┬────┘
    │               │               │               │
    │ POST /auth/register           │               │
    │ {email, password, name}       │               │
    │──────────────►│               │               │
    │               │               │               │
    │               │ 检查邮箱是否存在              │
    │               │──────────────►│               │
    │               │◄──────────────│               │
    │               │               │               │
    │               │ 创建用户      │               │
    │               │──────────────►│               │
    │               │               │               │
    │               │ 创建个人组织(默认)             │
    │               │──────────────►│               │
    │               │               │               │
    │               │ 用户加入个人组织(作为owner)    │
    │               │──────────────►│               │
    │               │               │               │
    │               │ 生成 JWT Token│               │
    │               │──────────────────────────────►│
    │               │◄──────────────────────────────│
    │               │               │               │
    │◄──────────────│ 返回 Token + 用户信息         │
    │               │               │               │
```

#### API 定义

**POST /api/v1/auth/register**

请求：
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "name": "张三"
}
```

响应：
```json
{
  "code": 0,
  "data": {
    "user": {
      "id": "usr_xxx",
      "email": "user@example.com",
      "name": "张三",
      "created_at": "2024-01-01T00:00:00Z"
    },
    "token": {
      "access_token": "eyJ...",
      "refresh_token": "eyJ...",
      "expires_in": 7200
    },
    "default_org": {
      "id": "org_xxx",
      "name": "张三的个人空间",
      "type": "personal"
    }
  }
}
```

错误码：
- `400001`：邮箱格式错误
- `400002`：密码强度不足
- `409001`：邮箱已被注册

---

### 2. 用户登录流程

```
┌────────┐      ┌────────┐      ┌────────┐      ┌────────┐
│  用户   │      │  API   │      │  DB    │      │ Redis  │
└───┬────┘      └───┬────┘      └───┬────┘      └───┬────┘
    │               │               │               │
    │ POST /auth/login              │               │
    │ {email, password}             │               │
    │──────────────►│               │               │
    │               │               │               │
    │               │ 查询用户      │               │
    │               │──────────────►│               │
    │               │◄──────────────│               │
    │               │               │               │
    │               │ 验证密码      │               │
    │               │               │               │
    │               │ 生成 JWT Token│               │
    │               │──────────────────────────────►│
    │               │◄──────────────────────────────│
    │               │               │               │
    │◄──────────────│ 返回 Token    │               │
    │               │               │               │
```

#### API 定义

**POST /api/v1/auth/login**

请求：
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

响应：
```json
{
  "code": 0,
  "data": {
    "user": {
      "id": "usr_xxx",
      "email": "user@example.com",
      "name": "张三"
    },
    "token": {
      "access_token": "eyJ...",
      "refresh_token": "eyJ...",
      "expires_in": 7200
    }
  }
}
```

---

### 3. 创建组织流程

```
┌────────┐      ┌────────┐      ┌────────┐      ┌────────┐
│  用户   │      │  API   │      │  DB    │      │ 通知服务 │
└───┬────┘      └───┬────┘      └───┬────┘      └───┬────┘
    │               │               │               │
    │ POST /organizations          │               │
    │ Authorization: Bearer <token> │               │
    │ {name, type, description}     │               │
    │──────────────►│               │               │
    │               │               │               │
    │               │ 验证 Token    │               │
    │               │               │               │
    │               │ 创建组织      │               │
    │               │──────────────►│               │
    │               │               │               │
    │               │ 创建者加入组织(作为owner)      │
    │               │──────────────►│               │
    │               │               │               │
    │◄──────────────│ 返回组织信息  │               │
    │               │               │               │
```

#### API 定义

**POST /api/v1/organizations**

请求头：
```
Authorization: Bearer <access_token>
```

请求：
```json
{
  "name": "产品研发组",
  "type": "team",
  "description": "负责产品研发的团队"
}
```

响应：
```json
{
  "code": 0,
  "data": {
    "id": "org_xxx",
    "name": "产品研发组",
    "type": "team",
    "description": "负责产品研发的团队",
    "owner_id": "usr_xxx",
    "created_at": "2024-01-01T00:00:00Z",
    "member_count": 1
  }
}
```

---

### 4. 邀请用户加入组织流程

```
┌────────┐      ┌────────┐      ┌────────┐      ┌────────┐      ┌────────┐
│ 管理员 │      │  API   │      │  DB    │      │ 通知   │      │被邀请用户│
└───┬────┘      └───┬────┘      └───┬────┘      └───┬────┘      └───┬────┘
    │               │               │               │               │
    │ POST /organizations/{id}/invitations         │               │
    │ {email, role: "member"}       │               │               │
    │──────────────►│               │               │               │
    │               │               │               │               │
    │               │ 验证管理员权限│               │               │
    │               │──────────────►│               │               │
    │               │◄──────────────│               │               │
    │               │               │               │               │
    │               │ 检查用户是否存在              │               │
    │               │──────────────►│               │               │
    │               │◄──────────────│               │               │
    │               │               │               │               │
    │               │ 创建邀请记录  │               │               │
    │               │──────────────►│               │               │
    │               │               │               │               │
    │               │               │ 发送邀请通知  │               │
    │               │               │──────────────►│──────────────►│
    │               │               │               │               │
    │◄──────────────│ 返回成功      │               │               │
    │               │               │               │               │
```

#### API 定义

**POST /api/v1/organizations/{org_id}/invitations**

请求：
```json
{
  "email": "newuser@example.com",
  "role": "member"
}
```

响应：
```json
{
  "code": 0,
  "data": {
    "invitation_id": "inv_xxx",
    "email": "newuser@example.com",
    "org_id": "org_xxx",
    "org_name": "产品研发组",
    "status": "pending",
    "expires_at": "2024-01-08T00:00:00Z"
  }
}
```

---

### 5. 用户接受邀请/加入组织流程

```
┌────────┐      ┌────────┐      ┌────────┐
│  用户   │      │  API   │      │  DB    │
└───┬────┘      └───┬────┘      └───┬────┘
    │               │               │
    │ POST /invitations/{id}/accept │
    │ Authorization: Bearer <token> │
    │──────────────►│               │
    │               │               │
    │               │ 验证邀请有效性│
    │               │──────────────►│
    │               │◄──────────────│
    │               │               │
    │               │ 用户加入组织  │
    │               │──────────────►│
    │               │               │
    │               │ 更新邀请状态  │
    │               │──────────────►│
    │               │               │
    │◄──────────────│ 返回组织信息  │
    │               │               │
```

#### API 定义

**POST /api/v1/invitations/{invitation_id}/accept**

响应：
```json
{
  "code": 0,
  "data": {
    "org": {
      "id": "org_xxx",
      "name": "产品研发组",
      "role": "member"
    }
  }
}
```

---

### 6. Agent 创建流程

```
┌────────┐      ┌────────┐      ┌────────┐
│  用户   │      │  API   │      │  DB    │
└───┬────┘      └───┬────┘      └───┬────┘
    │               │               │
    │ POST /agents                  │
    │ Authorization: Bearer <token> │
    │ {name, description, skills}    │
    │──────────────►│               │
    │               │               │
    │               │ 验证 Token    │               │
    │               │               │
    │               │ 创建 Agent    │
    │               │ owner_id = 当前用户           │
    │               │──────────────►│
    │               │               │
    │               │ 生成 Agent Token (用于接入)   │
    │               │──────────────►│
    │               │◄──────────────│
    │               │               │
    │◄──────────────│ 返回 Agent 信息 + Token        │
    │               │               │
```

#### API 定义

**POST /api/v1/agents**

请求：
```json
{
  "name": "数据分析助手",
  "description": "擅长数据分析和可视化，可以帮助处理 Excel、生成图表",
  "avatar": "https://example.com/avatar.png",
  "skills": [
    "数据分析",
    "Excel 处理",
    "图表生成"
  ],
  "metadata": {
    "model": "gpt-4",
    "endpoint": "https://api.example.com/agent"
  }
}
```

响应：
```json
{
  "code": 0,
  "data": {
    "id": "agt_xxx",
    "name": "数据分析助手",
    "description": "擅长数据分析和可视化...",
    "avatar": "https://example.com/avatar.png",
    "skills": ["数据分析", "Excel 处理", "图表生成"],
    "owner_id": "usr_xxx",
    "status": "inactive",
    "access_token": "agt_secret_xxx",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

> **注意**：`access_token` 仅在创建时返回一次，Agent 使用此 token 通过 WebSocket 连接系统。

---

### 7. Agent 申请加入组织流程

```
┌────────┐      ┌────────┐      ┌────────┐      ┌────────┐      ┌────────┐
│ Agent  │      │  API   │      │  DB    │      │ 通知   │      │ 管理员 │
└───┬────┘      └───┬────┘      └───┬────┘      └───┬────┘      └───┬────┘
    │               │               │               │               │
    │ POST /agents/{id}/join-requests              │               │
    │ Authorization: Bearer <agent_token>          │               │
    │ {org_id: "org_xxx"}           │               │               │
    │──────────────►│               │               │               │
    │               │               │               │               │
    │               │ 验证 Agent Token              │               │
    │               │──────────────►│               │               │
    │               │◄──────────────│               │               │
    │               │               │               │
    │               │ 验证 Owner 是否在组织中        │               │
    │               │──────────────►│               │               │
    │               │◄──────────────│               │               │
    │               │               │               │
    │               │ 创建加入申请  │               │               │
    │               │ status: pending               │               │
    │               │──────────────►│               │               │
    │               │               │               │
    │               │               │ 通知组织管理员│               │
    │               │               │──────────────►│──────────────►│
    │               │               │               │               │
    │◄──────────────│ 返回申请信息  │               │               │
    │               │               │               │               │
```

#### API 定义

**POST /api/v1/agents/{agent_id}/join-requests**

请求：
```json
{
  "org_id": "org_xxx"
}
```

响应：
```json
{
  "code": 0,
  "data": {
    "request_id": "jrq_xxx",
    "agent_id": "agt_xxx",
    "agent_name": "数据分析助手",
    "org_id": "org_xxx",
    "org_name": "产品研发组",
    "status": "pending",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### 8. 组织管理员审批 Agent 加入流程

```
┌────────┐      ┌────────┐      ┌────────┐      ┌────────┐
│ 管理员 │      │  API   │      │  DB    │      │ Agent  │
└───┬────┘      └───┬────┘      └───┬────┘      └───┬────┘
    │               │               │               │
    │ POST /join-requests/{id}/approve              │
    │ Authorization: Bearer <admin_token>            │
    │──────────────►│               │               │
    │               │               │               │
    │               │ 验证管理员权限│               │
    │               │──────────────►│               │
    │               │◄──────────────│               │
    │               │               │
    │               │ 更新申请状态为 approved       │
    │               │──────────────►│               │
    │               │               │
    │               │ Agent 加入组织│               │
    │               │──────────────►│               │
    │               │               │
    │               │ 通知 Agent    │               │
    │               │──────────────────────────────►│
    │               │               │               │
    │◄──────────────│ 返回成功      │               │
    │               │               │               │
```

#### API 定义

**POST /api/v1/join-requests/{request_id}/approve**

响应：
```json
{
  "code": 0,
  "data": {
    "request_id": "jrq_xxx",
    "status": "approved",
    "agent": {
      "id": "agt_xxx",
      "name": "数据分析助手"
    },
    "org": {
      "id": "org_xxx",
      "name": "产品研发组"
    }
  }
}
```

**POST /api/v1/join-requests/{request_id}/reject**

请求：
```json
{
  "reason": "该 Agent 的能力与组织需求不符"
}
```

---

### 9. Agent 连接系统流程

```
┌────────┐      ┌────────┐      ┌────────┐      ┌────────┐
│ Agent  │      │WebSocket│      │  DB    │      │ Redis  │
└───┬────┘      └───┬────┘      └───┬────┘      └───┬────┘
    │               │               │               │
    │ WebSocket 连接 ws://host/ws   │               │
    │──────────────►│               │               │
    │               │               │               │
    │ {type: "auth", token: "agt_xxx"}              │
    │──────────────►│               │               │
    │               │               │               │
    │               │ 验证 Agent Token              │
    │               │──────────────►│               │
    │               │◄──────────────│               │
    │               │               │               │
    │               │ 注册连接      │               │
    │               │──────────────────────────────►│
    │               │               │               │
    │               │ 更新 Agent 状态为 online      │
    │               │──────────────►│               │
    │               │               │               │
    │ {type: "auth_success", agent_id: "agt_xxx"}   │
    │◄──────────────│               │               │
    │               │               │               │
    │               │  开始接收消息 │               │
    │◄──────────────│               │               │
    │               │               │               │
```

---

### 10. 会话创建与消息发送流程

#### 创建会话

**POST /api/v1/conversations**

请求：
```json
{
  "org_id": "org_xxx",
  "type": "group",
  "name": "项目讨论组",
  "participant_ids": [
    {"type": "user", "id": "usr_aaa"},
    {"type": "user", "id": "usr_bbb"},
    {"type": "agent", "id": "agt_xxx"}
  ]
}
```

响应：
```json
{
  "code": 0,
  "data": {
    "id": "conv_xxx",
    "type": "group",
    "name": "项目讨论组",
    "org_id": "org_xxx",
    "participants": [
      {"type": "user", "id": "usr_aaa", "name": "张三"},
      {"type": "user", "id": "usr_bbb", "name": "李四"},
      {"type": "agent", "id": "agt_xxx", "name": "数据分析助手"}
    ],
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

#### 发送消息 (HTTP)

**POST /api/v1/conversations/{conv_id}/messages**

请求：
```json
{
  "content": "@数据分析助手 帮我分析一下这份销售数据",
  "content_type": "text"
}
```

#### 发送消息 (WebSocket)

```json
{
  "type": "message",
  "conversation_id": "conv_xxx",
  "content": "@数据分析助手 帮我分析一下这份销售数据",
  "content_type": "text"
}
```

#### 消息推送流程

```
┌────────┐      ┌────────┐      ┌────────┐      ┌────────┐      ┌────────┐
│  用户   │      │WebSocket│      │  DB    │      │ Redis  │      │ Agent  │
└───┬────┘      └───┬────┘      └───┬────┘      └───┬────┘      └───┬────┘
    │               │               │               │               │
    │ 发送消息      │               │               │               │
    │──────────────►│               │               │               │
    │               │               │               │               │
    │               │ 存储消息      │               │               │
    │               │──────────────►│               │               │
    │               │               │               │               │
    │               │ 发布到频道    │               │               │
    │               │──────────────────────────────►│               │
    │               │               │               │               │
    │               │ 推送给所有参与者               │               │
    │◄──────────────│               │               │──────────────►│
    │               │               │               │               │
    │               │ 如果有 @ 提及，特殊通知 Agent │               │
    │               │──────────────────────────────────────────────►│
    │               │               │               │               │
```

---

## API 总览

### 认证 API

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/auth/register` | 用户注册 |
| POST | `/api/v1/auth/login` | 用户登录 |
| POST | `/api/v1/auth/logout` | 用户登出 |
| POST | `/api/v1/auth/refresh` | 刷新 Token |

### 用户 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/users/me` | 获取当前用户信息 |
| PUT | `/api/v1/users/me` | 更新用户信息 |
| GET | `/api/v1/users/me/orgs` | 获取用户所属组织 |
| GET | `/api/v1/users/me/agents` | 获取用户的 Agent 列表 |

### 组织 API

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/organizations` | 创建组织 |
| GET | `/api/v1/organizations/{id}` | 获取组织详情 |
| PUT | `/api/v1/organizations/{id}` | 更新组织信息 |
| DELETE | `/api/v1/organizations/{id}` | 解散组织 |
| GET | `/api/v1/organizations/{id}/members` | 获取组织成员 |
| POST | `/api/v1/organizations/{id}/invitations` | 邀请用户加入 |
| GET | `/api/v1/organizations/{id}/agents` | 获取组织内的 Agent |
| PUT | `/api/v1/organizations/{id}/members/{user_id}` | 更新成员角色 |
| DELETE | `/api/v1/organizations/{id}/members/{user_id}` | 移除成员 |

### Agent API

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/agents` | 创建 Agent |
| GET | `/api/v1/agents/{id}` | 获取 Agent 详情 |
| PUT | `/api/v1/agents/{id}` | 更新 Agent 信息 |
| DELETE | `/api/v1/agents/{id}` | 删除 Agent |
| POST | `/api/v1/agents/{id}/join-requests` | 申请加入组织 |
| GET | `/api/v1/agents/{id}/join-requests` | 获取加入申请列表 |
| POST | `/api/v1/agents/{id}/regenerate-token` | 重新生成接入 Token |

### 加入申请 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/join-requests` | 获取待审批的申请列表 |
| POST | `/api/v1/join-requests/{id}/approve` | 批准申请 |
| POST | `/api/v1/join-requests/{id}/reject` | 拒绝申请 |

### 会话 API

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/conversations` | 创建会话 |
| GET | `/api/v1/conversations` | 获取会话列表 |
| GET | `/api/v1/conversations/{id}` | 获取会话详情 |
| PUT | `/api/v1/conversations/{id}` | 更新会话信息 |
| DELETE | `/api/v1/conversations/{id}` | 删除/退出会话 |
| POST | `/api/v1/conversations/{id}/participants` | 添加参与者 |
| DELETE | `/api/v1/conversations/{id}/participants/{pid}` | 移除参与者 |

### 消息 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/conversations/{id}/messages` | 获取消息历史 |
| POST | `/api/v1/conversations/{id}/messages` | 发送消息 |

---

## WebSocket 协议

### 连接

```
ws://host/ws?token=<access_token>
```

### 消息类型

#### 客户端 → 服务端

| 类型 | 说明 | 示例 |
|------|------|------|
| `auth` | 认证 | `{"type": "auth", "token": "xxx"}` |
| `message` | 发送消息 | `{"type": "message", "conversation_id": "xxx", "content": "hello"}` |
| `typing` | 正在输入 | `{"type": "typing", "conversation_id": "xxx"}` |
| `mark_read` | 标记已读 | `{"type": "mark_read", "conversation_id": "xxx"}` |
| `heartbeat` | 心跳 | `{"type": "heartbeat"}` |

#### 服务端 → 客户端

| 类型 | 说明 | 示例 |
|------|------|------|
| `auth_success` | 认证成功 | `{"type": "auth_success", "user_id": "xxx"}` |
| `auth_failed` | 认证失败 | `{"type": "auth_failed", "reason": "xxx"}` |
| `message` | 新消息 | 见下方详细格式 |
| `mention` | 被 @ 提及 | `{"type": "mention", ...}` |
| `invitation` | 邀请通知 | `{"type": "invitation", ...}` |
| `system` | 系统通知 | `{"type": "system", "content": "xxx"}` |
| `pong` | 心跳响应 | `{"type": "pong"}` |

### 消息格式

```json
{
  "type": "message",
  "data": {
    "id": "msg_xxx",
    "conversation_id": "conv_xxx",
    "sender": {
      "type": "user",
      "id": "usr_xxx",
      "name": "张三",
      "avatar": "https://..."
    },
    "content": "你好",
    "content_type": "text",
    "mentions": [
      {"type": "agent", "id": "agt_xxx", "name": "数据分析助手"}
    ],
    "created_at": "2024-01-01T12:00:00Z"
  }
}
```

---

## 快速开始

### 环境要求

- Go 1.21+
- Docker 20.10+
- Docker Compose 2.0+
- PostgreSQL 15+ (开发环境可选，使用 Docker)
- Redis 7+ (开发环境可选，使用 Docker)

### 一键部署

```bash
# 克隆项目
git clone https://github.com/your-org/openIM.git
cd openIM

# 复制配置文件
cp configs/config.example.yaml configs/config.yaml
cp .env.example .env

# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f
```

服务启动后：
- API：http://localhost:8080
- WebSocket：ws://localhost:8080/ws
- API 文档：http://localhost:8080/swagger

### 本地开发

```bash
# 安装依赖
go mod download

# 启动依赖服务
docker-compose -f docker-compose.dev.yml up -d

# 运行数据库迁移
make migrate-up

# 启动服务
make run

# 运行测试
make test
```

### 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `APP_ENV` | 运行环境 | `development` |
| `APP_PORT` | API 端口 | `8080` |
| `DB_HOST` | 数据库地址 | `localhost` |
| `DB_PORT` | 数据库端口 | `5432` |
| `DB_USER` | 数据库用户 | `postgres` |
| `DB_PASSWORD` | 数据库密码 | `postgres` |
| `DB_NAME` | 数据库名 | `openim` |
| `REDIS_ADDR` | Redis 地址 | `localhost:6379` |
| `JWT_SECRET` | JWT 密钥 | (必须设置) |
| `JWT_EXPIRE` | Token 过期时间(秒) | `7200` |

---

## 开发路线

### Phase 1: 核心功能 (MVP)

- [ ] 用户注册/登录
- [ ] 组织创建与管理
- [ ] Agent 创建与接入
- [ ] Agent 加入组织流程
- [ ] 单聊/群聊
- [ ] WebSocket 消息推送

### Phase 2: 增强

- [ ] 消息已读回执
- [ ] 消息搜索
- [ ] 文件/图片消息
- [ ] Agent 能力发现
- [ ] 邀请链接机制

### Phase 3: 扩展

- [ ] LLM 集成（可选）
- [ ] Agent 工具调用
- [ ] 消息加密
- [ ] 移动端 SDK
- [ ] 消息撤回/编辑

---

## 贡献指南

欢迎提交 Issue 和 Pull Request。

## 许可证

MIT License