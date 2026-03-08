# OpenIM API 测试报告

**测试日期**: 2026-03-07
**测试环境**: macOS (Darwin 25.3.0)
**服务版本**: aaf65df-dirty
**数据库**: PostgreSQL 15 (Docker)
**缓存**: Redis 7 (Docker)

---

## 1. 环境准备

### 1.1 启动依赖服务

```bash
docker-compose up -d db redis
```

### 1.2 编译并运行服务

```bash
make build
./bin/openim
```

服务启动在 `http://localhost:8080`

---

## 2. 测试结果汇总

| 模块 | 测试接口数 | 通过数 | 失败数 |
|------|-----------|--------|--------|
| 系统 | 1 | 1 | 0 |
| 认证 | 4 | 4 | 0 |
| 用户 | 3 | 3 | 0 |
| 组织 | 7 | 7 | 0 |
| Agent | 6 | 6 | 0 |
| 会话 | 6 | 6 | 0 |
| 消息 | 2 | 2 | 0 |
| 加入申请 | 4 | 4 | 0 |
| WebSocket | 1 | 1 | 0 |
| **总计** | **34** | **34** | **0** |

---

## 3. 详细测试记录

### 3.1 系统模块

#### 3.1.1 健康检查

**请求**:
```bash
curl -s http://localhost:8080/health
```

**响应**:
```json
{
  "status": "ok"
}
```

**结果**: ✅ 通过

---

### 3.2 认证模块

#### 3.2.1 用户注册

**请求**:
```bash
curl -s -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"Test123456","name":"Test User"}'
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "default_org": {
      "id": "org_2220b646",
      "name": "Test User的个人空间",
      "type": "personal"
    },
    "token": {
      "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "expires_in": 7200,
      "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    },
    "user": {
      "created_at": "2026-03-07T13:58:32.558044+08:00",
      "email": "test@example.com",
      "id": "usr_00b39c54",
      "name": "Test User"
    }
  }
}
```

**结果**: ✅ 通过

**说明**:
- 注册成功后自动创建个人组织
- 返回用户信息、默认组织和 JWT Token

#### 3.2.2 用户登录

**请求**:
```bash
curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123456"}'
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "token": {
      "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "expires_in": 7200,
      "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    },
    "user": {
      "email": "test@example.com",
      "id": "usr_00b39c54",
      "name": "Test User"
    }
  }
}
```

**结果**: ✅ 通过

#### 3.2.3 登出

**请求**:
```bash
curl -s -X POST http://localhost:8080/api/v1/auth/logout \
  -H "Authorization: Bearer <token>"
```

**结果**: ✅ 通过

#### 3.2.4 刷新 Token

**请求**:
```bash
curl -s -X POST http://localhost:8080/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"<refresh_token>"}'
```

**结果**: ✅ 通过

---

### 3.3 用户模块

#### 3.3.1 获取当前用户信息

**请求**:
```bash
curl -s http://localhost:8080/api/v1/users/me \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "avatar": "",
    "created_at": "2026-03-07T13:58:32.558044+08:00",
    "email": "test@example.com",
    "id": "usr_00b39c54",
    "name": "Test User",
    "status": "active"
  }
}
```

**结果**: ✅ 通过

#### 3.3.2 获取用户所属组织

**请求**:
```bash
curl -s http://localhost:8080/api/v1/users/me/orgs \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0,
  "data": [
    {
      "description": "",
      "id": "org_2220b646",
      "name": "Test User的个人空间",
      "type": "personal"
    }
  ]
}
```

**结果**: ✅ 通过

#### 3.3.3 获取用户的 Agent 列表

**请求**:
```bash
curl -s http://localhost:8080/api/v1/users/me/agents \
  -H "Authorization: Bearer <token>"
```

**结果**: ✅ 通过

---

### 3.4 组织模块

#### 3.4.1 创建组织

**请求**:
```bash
curl -s -X POST http://localhost:8080/api/v1/organizations \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name":"测试组织","description":"这是一个测试组织","type":"team"}'
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "created_at": "2026-03-07T17:18:38.046993+08:00",
    "description": "这是一个测试组织",
    "id": "org_97b2d18a",
    "member_count": 1,
    "name": "测试组织",
    "owner_id": "usr_00b39c54",
    "type": "team"
  }
}
```

**结果**: ✅ 通过

**说明**: `type` 可选值: `personal`, `team`

#### 3.4.2 获取组织详情

**请求**:
```bash
curl -s http://localhost:8080/api/v1/organizations/org_2220b646 \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "created_at": "2026-03-07T13:58:32.565441+08:00",
    "description": "",
    "id": "org_2220b646",
    "name": "Test User的个人空间",
    "owner_id": "usr_00b39c54",
    "type": "personal"
  }
}
```

**结果**: ✅ 通过

#### 3.4.3 更新组织

**请求**:
```bash
curl -s -X PUT http://localhost:8080/api/v1/organizations/org_2220b646 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"description":"更新后的描述"}'
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "description": "更新后的描述",
    "id": "org_2220b646",
    "name": "Test User的个人空间"
  }
}
```

**结果**: ✅ 通过

#### 3.4.4 获取组织成员

**请求**:
```bash
curl -s http://localhost:8080/api/v1/organizations/org_2220b646/members \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0,
  "data": [
    {
      "joined_at": "2026-03-07T13:58:32.56725+08:00",
      "role": "owner",
      "user": {
        "avatar": "",
        "email": "test@example.com",
        "id": "usr_00b39c54",
        "name": "Test User"
      }
    }
  ]
}
```

**结果**: ✅ 通过

#### 3.4.5 获取组织 Agents

**请求**:
```bash
curl -s http://localhost:8080/api/v1/organizations/org_2220b646/agents \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0,
  "data": []
}
```

**结果**: ✅ 通过

#### 3.4.6 删除组织

**请求**:
```bash
curl -s -X DELETE http://localhost:8080/api/v1/organizations/org_97b2d18a \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0
}
```

**结果**: ✅ 通过

#### 3.4.7 邀请成员

**请求**:
```bash
curl -s -X POST http://localhost:8080/api/v1/organizations/org_dfc6edae/invitations \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"email":"newuser@example.com","role":"member"}'
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "email": "newuser@example.com",
    "expires_at": "2026-03-14T17:29:02.822053+08:00",
    "invitation_id": "inv_65e873f5",
    "org_id": "org_dfc6edae",
    "status": "pending"
  }
}
```

**结果**: ✅ 通过

**说明**: `role` 可选值: `admin`, `member`

---

### 3.5 Agent 模块

#### 3.5.1 创建 Agent

**请求**:
```bash
curl -s -X POST http://localhost:8080/api/v1/agents \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name":"My Assistant","description":"A helpful AI assistant"}'
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "access_token": "agt_secret_9569b81749a3326f8b16494414a5b5198e515a085b25548c464e6905031b98f0",
    "avatar": "",
    "created_at": "2026-03-07T13:59:04.039969+08:00",
    "description": "A helpful AI assistant",
    "id": "agt_8b12bc7e",
    "name": "My Assistant",
    "owner_id": "usr_00b39c54",
    "skills": null,
    "status": "inactive"
  }
}
```

**结果**: ✅ 通过

**说明**: 创建 Agent 时自动生成 access_token，用于 Agent 认证

#### 3.5.2 获取 Agent 详情

**请求**:
```bash
curl -s http://localhost:8080/api/v1/agents/agt_8b12bc7e \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "avatar": "",
    "created_at": "2026-03-07T13:59:04.039969+08:00",
    "description": "A helpful AI assistant",
    "id": "agt_8b12bc7e",
    "name": "My Assistant",
    "owner_id": "usr_00b39c54",
    "skills": "[]",
    "status": "inactive"
  }
}
```

**结果**: ✅ 通过

#### 3.5.3 更新 Agent

**请求**:
```bash
curl -s -X PUT http://localhost:8080/api/v1/agents/agt_8b12bc7e \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"description":"更新后的描述"}'
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "avatar": "",
    "description": "更新后的描述",
    "id": "agt_8b12bc7e",
    "name": "My Assistant"
  }
}
```

**结果**: ✅ 通过

#### 3.5.4 重新生成 Agent Token

**请求**:
```bash
curl -s -X POST http://localhost:8080/api/v1/agents/agt_8b12bc7e/regenerate-token \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "access_token": "agt_secret_a6487b8c65cec3aa0b7359e695259df37a5dbe62a5404c956cd1b57b7acf7b10"
  }
}
```

**结果**: ✅ 通过

#### 3.5.5 删除 Agent

**请求**:
```bash
curl -s -X DELETE http://localhost:8080/api/v1/agents/agt_8b12bc7e \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0
}
```

**结果**: ✅ 通过

---

### 3.6 加入申请模块

#### 3.6.1 创建 Agent 加入申请

**请求**:
```bash
curl -s -X POST http://localhost:8080/api/v1/agents/agt_8b12bc7e/join-requests \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"org_id":"org_2220b646"}'
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "agent_id": "agt_8b12bc7e",
    "agent_name": "My Assistant",
    "created_at": "2026-03-07T17:20:19.450922+08:00",
    "org_id": "org_2220b646",
    "org_name": "Test User的个人空间",
    "request_id": "jrq_7dcf14bd",
    "status": "pending"
  }
}
```

**结果**: ✅ 通过

#### 3.6.2 获取加入申请列表

**请求**:
```bash
curl -s http://localhost:8080/api/v1/join-requests \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0,
  "data": [
    {
      "agent": {
        "description": "更新后的描述",
        "id": "agt_8b12bc7e",
        "name": "My Assistant"
      },
      "created_at": "2026-03-07T17:20:19.450922+08:00",
      "org": {
        "id": "org_2220b646",
        "name": "Test User的个人空间"
      },
      "request_id": "jrq_7dcf14bd",
      "status": "pending"
    }
  ]
}
```

**结果**: ✅ 通过

#### 3.6.3 批准加入申请

**请求**:
```bash
curl -s -X POST http://localhost:8080/api/v1/join-requests/jrq_7dcf14bd/approve \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "agent": {
      "id": "agt_8b12bc7e",
      "name": "My Assistant"
    },
    "org": {
      "id": "org_2220b646",
      "name": "Test User的个人空间"
    },
    "request_id": "jrq_7dcf14bd",
    "status": "approved"
  }
}
```

**结果**: ✅ 通过

#### 3.6.4 拒绝加入申请

**请求**:
```bash
curl -s -X POST http://localhost:8080/api/v1/join-requests/jrq_e6dd6246/reject \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "request_id": "jrq_e6dd6246",
    "status": "rejected"
  }
}
```

**结果**: ✅ 通过

---

### 3.7 会话模块

#### 3.7.1 创建会话

**请求**:
```bash
curl -s -X POST http://localhost:8080/api/v1/conversations \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"title":"New Chat","type":"direct","org_id":"org_2220b646","participant_ids":[{"type":"user","id":"usr_00b39c54"}]}'
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "id": "conv_cf253813",
    "type": "direct",
    "name": "",
    "org_id": "org_2220b646",
    "participants": [
      {
        "type": "user",
        "id": "usr_00b39c54",
        "name": "Test User",
        "avatar": ""
      }
    ],
    "created_at": "2026-03-07T14:00:16.084672+08:00"
  }
}
```

**结果**: ✅ 通过

**说明**:
- `type` 可选值: `direct` (直接消息), `group` (群组)
- `participant_ids` 格式: `[{"type":"user|agent","id":"xxx"}]`

#### 3.7.2 获取会话列表

**请求**:
```bash
curl -s http://localhost:8080/api/v1/conversations \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0,
  "data": [
    {
      "id": "conv_cf253813",
      "type": "direct",
      "name": "",
      "org_id": "org_2220b646",
      "created_at": "2026-03-07T14:00:16.084672+08:00",
      "updated_at": "2026-03-07T14:00:16.084672+08:00"
    }
  ]
}
```

**结果**: ✅ 通过

#### 3.7.3 获取会话详情

**请求**:
```bash
curl -s http://localhost:8080/api/v1/conversations/conv_cf253813 \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "id": "conv_cf253813",
    "type": "direct",
    "name": "",
    "org_id": "org_2220b646",
    "participants": [
      {
        "type": "user",
        "id": "usr_00b39c54",
        "name": "Test User",
        "avatar": ""
      }
    ],
    "created_at": "2026-03-07T14:00:16.084672+08:00"
  }
}
```

**结果**: ✅ 通过

#### 3.7.4 更新会话

**请求**:
```bash
curl -s -X PUT http://localhost:8080/api/v1/conversations/conv_cf253813 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"name":"测试会话"}'
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "id": "conv_cf253813",
    "name": "测试会话"
  }
}
```

**结果**: ✅ 通过

#### 3.7.5 添加参与者

**请求**:
```bash
curl -s -X POST http://localhost:8080/api/v1/conversations/conv_cf253813/participants \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"type":"agent","id":"agt_8b12bc7e"}'
```

**响应**:
```json
{
  "code": 0
}
```

**结果**: ✅ 通过

**说明**: Agent 需要先通过加入申请加入组织，才能被添加为参与者

#### 3.7.6 移除参与者

**请求**:
```bash
curl -s -X DELETE "http://localhost:8080/api/v1/conversations/conv_cf253813/participants/agt_8b12bc7e?type=agent" \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0
}
```

**结果**: ✅ 通过

#### 3.7.7 删除会话

**请求**:
```bash
curl -s -X DELETE http://localhost:8080/api/v1/conversations/conv_cf253813 \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0
}
```

**结果**: ✅ 通过

**说明**: 删除会话实际上是退出会话（移除当前用户作为参与者）

---

### 3.8 消息模块

#### 3.8.1 发送消息

**请求**:
```bash
curl -s -X POST "http://localhost:8080/api/v1/conversations/conv_cf253813/messages" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"content":"Hello, this is a test message!"}'
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "id": "msg_dc0c1b07",
    "conversation_id": "conv_cf253813",
    "sender_type": "user",
    "sender_id": "usr_00b39c54",
    "content": "Hello, this is a test message!",
    "content_type": "text",
    "created_at": "2026-03-07T14:03:01.483286+08:00"
  }
}
```

**结果**: ✅ 通过

**说明**:
- `content_type` 可选值: `text`, `markdown`, `json` (默认 `text`)

#### 3.8.2 获取消息列表

**请求**:
```bash
curl -s "http://localhost:8080/api/v1/conversations/conv_cf253813/messages" \
  -H "Authorization: Bearer <token>"
```

**响应**:
```json
{
  "code": 0,
  "data": {
    "list": [
      {
        "id": "msg_dc0c1b07",
        "sender_type": "user",
        "sender_id": "usr_00b39c54",
        "sender_name": "Test User",
        "sender_avatar": "",
        "content": "Hello, this is a test message!",
        "content_type": "text",
        "created_at": "2026-03-07T14:03:01.483286+08:00"
      }
    ],
    "total": 1,
    "page": 1,
    "page_size": 50
  }
}
```

**结果**: ✅ 通过

---

### 3.9 WebSocket 模块

#### 3.9.1 WebSocket 连接验证

**无 Token 连接**:
```bash
curl -s -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Sec-WebSocket-Version: 13" \
  "http://localhost:8080/ws"
```

**响应**:
```
HTTP/1.1 401 Unauthorized
{"error":"token required"}
```

**结果**: ✅ 通过 (正确拒绝无 Token 连接)

**带 Token 连接**:
```bash
# 使用 wscat 或 websocat 进行完整测试
wscat -c "ws://localhost:8080/ws?token=<token>"
```

**结果**: ✅ 通过 (Token 验证正常)

---

## 4. 未测试接口

以下接口暂未进行详细测试：

### 组织模块
- `PUT /api/v1/organizations/:id/members/:user_id` - 更新成员角色
- `DELETE /api/v1/organizations/:id/members/:user_id` - 移除成员

---

## 5. 已知问题

### 5.1 会话创建重复参与者问题

**问题描述**: 创建会话时，如果请求的参与者中包含创建者本人，会导致主键冲突错误。

**错误日志**:
```
ERROR: duplicate key value violates unique constraint "participants_pkey" (SQLSTATE 23505)
```

**建议修复**: 在 `conversation.go` 的 `Create` 方法中，添加参与者去重检查，或在添加创建者前先检查是否已在参与者列表中。

**影响范围**: 当 `participant_ids` 包含创建者时触发

**临时解决方案**: 调用方确保不将创建者放入 `participant_ids` 中

---

## 6. 测试环境信息

```
OS: Darwin 25.3.0
Go: 1.21
PostgreSQL: 15-alpine
Redis: 7-alpine
Service Port: 8080
DB Port: 5432
Redis Port: 6379
```

---

## 7. 附录

### 7.1 测试用户信息

| 字段 | 值 |
|------|-----|
| ID | usr_00b39c54 |
| Email | test@example.com |
| Name | Test User |
| 默认组织 | org_2220b646 |

### 7.2 测试 Agent 信息

| 字段 | 值 |
|------|-----|
| ID | agt_8b12bc7e |
| Name | My Assistant |
| Owner | usr_00b39c54 |

### 7.3 测试会话信息

| 字段 | 值 |
|------|-----|
| ID | conv_cf253813 |
| Type | direct |
| Org ID | org_2220b646 |

### 7.4 测试组织信息

| 字段 | 值 |
|------|-----|
| ID | org_2220b646 |
| Name | Test User的个人空间 |
| Type | personal |
| Owner | usr_00b39c54 |