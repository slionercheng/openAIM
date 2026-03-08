# 好友系统设计文档

## 概述

本文档描述了 OpenAIM 项目的好友系统设计，包括数据库模型、API 接口和业务逻辑。

---

## 1. 数据库设计

### 1.1 friendships 表

好友关系表，用于存储用户之间的好友关系。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | VARCHAR(36) | 主键，UUID |
| requester_id | VARCHAR(36) | 请求者用户ID，外键关联 users.id |
| addressee_id | VARCHAR(36) | 接收者用户ID，外键关联 users.id |
| status | VARCHAR(20) | 关系状态：pending/accepted/rejected/blocked |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |
| deleted_at | DATETIME | 软删除时间 |

**索引设计：**
- `idx_friendships_requester_id` - 请求者ID索引
- `idx_friendships_addressee_id` - 接收者ID索引
- `idx_friendships_status` - 状态索引
- `uniq_friendships_pair` - 唯一约束 (requester_id, addressee_id)

**状态说明：**

| 状态 | 说明 |
|------|------|
| pending | 好友请求待处理 |
| accepted | 已接受，成为好友 |
| rejected | 已拒绝 |
| blocked | 已拉黑 |

### 1.2 关系图

```
┌─────────────┐         ┌─────────────┐
│   users     │         │ friendships │
├─────────────┤         ├─────────────┤
│ id          │◄────────│ requester_id│
│ email       │         │ addressee_id│────►│ users.id
│ name        │         │ status      │
│ avatar      │         │ created_at  │
│ status      │         │ updated_at  │
└─────────────┘         └─────────────┘
```

---

## 2. API 接口设计

### 2.1 用户搜索

**接口：** `GET /api/v1/users/search`

**描述：** 根据关键词搜索用户（按邮箱或名称）

**权限：** 需要登录

**请求参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| q | string | 是 | 搜索关键词 |
| page | int | 否 | 页码，默认 1 |
| page_size | int | 否 | 每页数量，默认 20，最大 50 |

**响应示例：**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "total": 10,
    "page": 1,
    "page_size": 20,
    "items": [
      {
        "id": "user-uuid",
        "email": "user@example.com",
        "name": "John Doe",
        "avatar": "https://...",
        "status": "active",
        "friendship_status": "none"
      }
    ]
  }
}
```

**friendship_status 说明：**

| 值 | 说明 |
|------|------|
| none | 无好友关系 |
| pending_sent | 已发送好友请求，待对方处理 |
| pending_received | 收到好友请求，待自己处理 |
| accepted | 已是好友 |
| blocked | 已被拉黑 |

---

### 2.2 获取好友列表

**接口：** `GET /api/v1/friends`

**描述：** 获取当前用户的好友列表

**权限：** 需要登录

**请求参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| page | int | 否 | 页码，默认 1 |
| page_size | int | 否 | 每页数量，默认 20 |

**响应示例：**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "total": 5,
    "page": 1,
    "page_size": 20,
    "items": [
      {
        "id": "friendship-id",
        "user": {
          "id": "user-uuid",
          "email": "friend@example.com",
          "name": "Jane Doe",
          "avatar": "https://...",
          "status": "active"
        },
        "created_at": "2026-03-07T10:00:00Z"
      }
    ]
  }
}
```

---

### 2.3 获取好友请求列表

**接口：** `GET /api/v1/friends/requests`

**描述：** 获取收到的好友请求列表

**权限：** 需要登录

**请求参数：**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| status | string | 否 | 筛选状态：pending/accepted/rejected，默认 pending |
| page | int | 否 | 页码，默认 1 |
| page_size | int | 否 | 每页数量，默认 20 |

**响应示例：**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "total": 3,
    "page": 1,
    "page_size": 20,
    "items": [
      {
        "id": "friendship-id",
        "requester": {
          "id": "user-uuid",
          "email": "requester@example.com",
          "name": "Bob Smith",
          "avatar": "https://..."
        },
        "status": "pending",
        "created_at": "2026-03-07T10:00:00Z"
      }
    ]
  }
}
```

---

### 2.4 发送好友请求

**接口：** `POST /api/v1/friends/request`

**描述：** 向指定用户发送好友请求

**权限：** 需要登录

**请求体：**

```json
{
  "user_id": "target-user-uuid"
}
```

**响应示例：**

```json
{
  "code": 0,
  "message": "好友请求已发送",
  "data": {
    "id": "friendship-id",
    "requester_id": "my-user-id",
    "addressee_id": "target-user-id",
    "status": "pending",
    "created_at": "2026-03-07T10:00:00Z"
  }
}
```

**错误码：**

| code | message |
|------|---------|
| 400001 | 参数错误 |
| 400002 | 不能添加自己为好友 |
| 400003 | 已经是好友或已发送请求 |
| 404001 | 用户不存在 |

---

### 2.5 接受好友请求

**接口：** `POST /api/v1/friends/requests/:id/accept`

**描述：** 接受好友请求

**权限：** 需要登录，且必须是请求的接收者

**路径参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| id | string | 好友请求ID |

**响应示例：**

```json
{
  "code": 0,
  "message": "已接受好友请求",
  "data": {
    "id": "friendship-id",
    "status": "accepted",
    "updated_at": "2026-03-07T10:00:00Z"
  }
}
```

---

### 2.6 拒绝好友请求

**接口：** `POST /api/v1/friends/requests/:id/reject`

**描述：** 拒绝好友请求

**权限：** 需要登录，且必须是请求的接收者

**路径参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| id | string | 好友请求ID |

**响应示例：**

```json
{
  "code": 0,
  "message": "已拒绝好友请求",
  "data": {
    "id": "friendship-id",
    "status": "rejected",
    "updated_at": "2026-03-07T10:00:00Z"
  }
}
```

---

### 2.7 删除好友

**接口：** `DELETE /api/v1/friends/:id`

**描述：** 删除好友关系

**权限：** 需要登录

**路径参数：**

| 参数 | 类型 | 说明 |
|------|------|------|
| id | string | 好友关系ID（friendship id）或好友用户ID |

**响应示例：**

```json
{
  "code": 0,
  "message": "已删除好友",
  "data": null
}
```

---

## 3. 业务逻辑

### 3.1 发送好友请求流程

```
1. 验证参数（user_id 不能为空）
2. 检查目标用户是否存在
3. 检查是否是自己（不能添加自己为好友）
4. 检查是否已存在好友关系（双向检查）
   - 查询 requester_id = current_user AND addressee_id = target_user
   - 查询 requester_id = target_user AND addressee_id = current_user
5. 如果已存在记录：
   - status = pending: 返回"已发送请求"
   - status = accepted: 返回"已经是好友"
   - status = rejected: 更新为 pending
   - status = blocked: 返回"无法发送请求"
6. 如果不存在记录，创建新的 friendship 记录
```

### 3.2 接受好友请求流程

```
1. 查找好友请求记录
2. 验证当前用户是 addressee
3. 验证状态为 pending
4. 更新状态为 accepted
5. 可选：创建直接会话（direct conversation）
```

### 3.3 删除好友流程

```
1. 查找好友关系记录
2. 验证当前用户是 requester 或 addressee
3. 验证状态为 accepted
4. 软删除记录（或更新状态）
```

---

## 4. 数据库迁移

### 4.1 SQL 迁移脚本

```sql
-- 创建 friendships 表
CREATE TABLE friendships (
    id VARCHAR(36) PRIMARY KEY,
    requester_id VARCHAR(36) NOT NULL,
    addressee_id VARCHAR(36) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME,

    INDEX idx_friendships_requester_id (requester_id),
    INDEX idx_friendships_addressee_id (addressee_id),
    INDEX idx_friendships_status (status),
    UNIQUE INDEX uniq_friendships_pair (requester_id, addressee_id),

    FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (addressee_id) REFERENCES users(id) ON DELETE CASCADE
);
```

---

## 5. 实现计划

### 阶段一：后端实现

1. ✅ 创建设计文档
2. ⬜ 创建 Friendship 数据模型 (`internal/domain/friendship/`)
3. ⬜ 创建 Friendship Repository
4. ⬜ 创建 Friendship Handler
5. ⬜ 添加用户搜索功能到 UserHandler
6. ⬜ 注册路由到 main.go
7. ⬜ 数据库迁移

### 阶段二：客户端实现

1. ⬜ 创建 FriendshipService
2. ⬜ 创建 FriendViewModel
3. ⬜ 创建搜索用户界面
4. ⬜ 创建好友列表界面
5. ⬜ 创建好友请求通知
6. ⬜ 集成到主界面

---

## 6. API 路由汇总

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/users/search` | 搜索用户 |
| GET | `/api/v1/friends` | 获取好友列表 |
| GET | `/api/v1/friends/requests` | 获取好友请求 |
| POST | `/api/v1/friends/request` | 发送好友请求 |
| POST | `/api/v1/friends/requests/:id/accept` | 接受好友请求 |
| POST | `/api/v1/friends/requests/:id/reject` | 拒绝好友请求 |
| DELETE | `/api/v1/friends/:id` | 删除好友 |