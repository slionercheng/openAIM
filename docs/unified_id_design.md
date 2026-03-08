# 统一消息ID设计文档

## 概述

本文档描述 OpenIM 系统的统一消息ID设计方案，用于保证所有消息类型的唯一性和可追溯性。

---

## 1. 设计目标

1. **全局唯一** - 所有消息ID在系统范围内唯一
2. **类型可识别** - 通过ID前缀可识别消息类型
3. **时间有序** - ID包含时间信息，支持按时间排序
4. **易于追溯** - 支持全链路追踪

---

## 2. ID格式设计

### 2.1 基本格式

```
{type}_{timestamp}_{random}
```

| 部分 | 长度 | 说明 |
|------|------|------|
| type | 3-5字符 | 消息类型前缀 |
| timestamp | 14字符 | YYYYMMDDHHMMSS |
| random | 6字符 | 随机字符 |
| 分隔符 | 2字符 | 下划线 |

**总长度**: 约 25-27 字符

### 2.2 类型前缀定义

| 前缀 | 类型 | 说明 |
|------|------|------|
| `usr` | User | 用户 |
| `agt` | Agent | AI代理 |
| `org` | Organization | 组织 |
| `conv` | Conversation | 会话 |
| `msg` | Message | 聊天消息 |
| `freq` | FriendRequest | 好友请求 |
| `jreq` | JoinRequest | 加入请求 |
| `inv` | Invitation | 邀请 |
| `ntf` | Notification | 系统通知 |
| `evt` | Event | 事件 |

### 2.3 ID示例

```
usr_20260308123456_abc123    # 用户ID
agt_20260308123457_def456    # Agent ID
msg_20260308123458_ghi789    # 聊天消息
freq_20260308123459_jkl012   # 好友请求
ntf_20260308123500_mno345    # 系统通知
```

---

## 3. 事件/通知系统设计

### 3.1 统一事件表 (events)

```sql
CREATE TABLE events (
    id VARCHAR(30) PRIMARY KEY,           -- 统一ID
    type VARCHAR(20) NOT NULL,             -- 事件类型
    sender_type VARCHAR(20) NOT NULL,      -- user/agent/system
    sender_id VARCHAR(30) NOT NULL,        -- 发送者ID
    receiver_type VARCHAR(20),             -- user/agent/conversation
    receiver_id VARCHAR(30),               -- 接收者ID
    payload JSONB,                         -- 事件载荷
    status VARCHAR(20) DEFAULT 'pending',  -- pending/delivered/read
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP,

    INDEX idx_events_type (type),
    INDEX idx_events_sender (sender_type, sender_id),
    INDEX idx_events_receiver (receiver_type, receiver_id),
    INDEX idx_events_status (status),
    INDEX idx_events_created_at (created_at)
);
```

### 3.2 事件类型定义

| 类型 | 说明 | payload 示例 |
|------|------|-------------|
| `friend_request` | 好友请求 | `{"friendship_id": "freq_xxx", "requester": {...}}` |
| `friend_accepted` | 好友请求已接受 | `{"friendship_id": "freq_xxx", "user": {...}}` |
| `join_request` | 加入组织请求 | `{"join_request_id": "jreq_xxx", "org": {...}}` |
| `join_approved` | 加入请求已批准 | `{"org": {...}, "role": "member"}` |
| `org_invitation` | 组织邀请 | `{"invitation_id": "inv_xxx", "org": {...}}` |
| `chat_message` | 聊天消息 | `{"message_id": "msg_xxx", "conversation_id": "conv_xxx", ...}` |
| `system_notification` | 系统通知 | `{"title": "...", "content": "..."}` |

### 3.3 事件状态流转

```
pending → delivered → read
    ↓
  expired (可选，用于限时事件)
```

---

## 4. 实现方案

### 4.1 ID生成器

```go
// pkg/idgen/idgen.go
package idgen

import (
    "fmt"
    "time"
    "github.com/sony/sonyflake"
)

const (
    TypeUser      = "usr"
    TypeAgent     = "agt"
    TypeOrg       = "org"
    TypeConv      = "conv"
    TypeMessage   = "msg"
    TypeFriendReq = "freq"
    TypeJoinReq   = "jreq"
    TypeInvitation = "inv"
    TypeNotification = "ntf"
    TypeEvent     = "evt"
)

var sf *sonyflake.Sonyflake

func Init(machineID uint16) {
    sf = sonyflake.NewSonyflake(sonyflake.Settings{
        MachineID: func() (uint16, error) { return machineID, nil },
    })
}

// Generate 生成带类型前缀的ID
func Generate(typePrefix string) string {
    id, _ := sf.NextID()
    return fmt.Sprintf("%s_%d", typePrefix, id)
}

// GenerateWithTime 生成带时间的ID
func GenerateWithTime(typePrefix string) string {
    now := time.Now().Format("20060102150405")
    random := generateRandom(6)
    return fmt.Sprintf("%s_%s_%s", typePrefix, now, random)
}
```

### 4.2 事件模型

```go
// internal/domain/event/event.go
package event

import (
    "time"
    "gorm.io/gorm"
)

type EventType string

const (
    EventTypeFriendRequest   EventType = "friend_request"
    EventTypeFriendAccepted  EventType = "friend_accepted"
    EventTypeJoinRequest     EventType = "join_request"
    EventTypeJoinApproved    EventType = "join_approved"
    EventTypeOrgInvitation   EventType = "org_invitation"
    EventTypeChatMessage     EventType = "chat_message"
    EventTypeSystemNotification EventType = "system_notification"
)

type EventStatus string

const (
    EventStatusPending    EventStatus = "pending"
    EventStatusDelivered  EventStatus = "delivered"
    EventStatusRead       EventStatus = "read"
    EventStatusExpired    EventStatus = "expired"
)

type Event struct {
    ID           string       `gorm:"primaryKey;type:varchar(30)" json:"id"`
    Type         EventType    `gorm:"type:varchar(20);not null;index" json:"type"`
    SenderType   string       `gorm:"type:varchar(20);not null" json:"sender_type"`
    SenderID     string       `gorm:"type:varchar(30);not null" json:"sender_id"`
    ReceiverType string       `gorm:"type:varchar(20)" json:"receiver_type"`
    ReceiverID   string       `gorm:"type:varchar(30)" json:"receiver_id"`
    Payload      JSONB        `gorm:"type:jsonb" json:"payload"`
    Status       EventStatus  `gorm:"type:varchar(20);default:'pending'" json:"status"`
    CreatedAt    time.Time    `json:"created_at"`
    UpdatedAt    time.Time    `json:"updated_at"`
    DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

type JSONB map[string]interface{}

func (Event) TableName() string {
    return "events"
}
```

---

## 5. 迁移计划

### 5.1 第一阶段：创建基础设施

1. 创建 `pkg/idgen` ID生成器包
2. 创建 `internal/domain/event` 事件模型
3. 添加数据库迁移

### 5.2 第二阶段：更新现有代码

1. 替换所有 `uuid.New()` 调用为 `idgen.Generate()`
2. 更新 Handler 中的ID生成逻辑
3. 保持现有API兼容性

### 5.3 第三阶段：实现事件系统

1. 创建事件服务
2. 集成到好友请求、加入请求等流程
3. 添加WebSocket事件推送

---

## 6. 使用示例

### 6.1 创建好友请求事件

```go
// 发送好友请求时
event := &event.Event{
    ID:           idgen.Generate(idgen.TypeFriendReq),
    Type:         event.EventTypeFriendRequest,
    SenderType:   "user",
    SenderID:     currentUserID,
    ReceiverType: "user",
    ReceiverID:   targetUserID,
    Payload: map[string]interface{}{
        "friendship_id": friendshipID,
        "requester": map[string]interface{}{
            "id":    currentUserID,
            "name":  currentUser.Name,
            "email": currentUser.Email,
        },
    },
}
eventRepo.Create(ctx, event)

// 推送给接收者
wsHub.SendToUser(targetUserID, event)
```

### 6.2 客户端处理

```json
{
    "id": "freq_20260308123459_jkl012",
    "type": "friend_request",
    "sender_type": "user",
    "sender_id": "usr_20260308120000_abc123",
    "receiver_type": "user",
    "receiver_id": "usr_20260308120100_def456",
    "payload": {
        "friendship_id": "freq_20260308123459_jkl012",
        "requester": {
            "id": "usr_20260308120000_abc123",
            "name": "张三",
            "email": "zhangsan@example.com"
        }
    },
    "status": "pending",
    "created_at": "2026-03-08T12:34:59Z"
}
```

---

## 7. 优势总结

1. **统一接口** - 所有消息类型使用相同的数据结构
2. **易于扩展** - 新增消息类型只需添加类型常量
3. **便于追踪** - ID包含类型和时间信息
4. **简化客户端** - 统一的消息处理逻辑
5. **支持推送** - 事件表可直接用于推送队列