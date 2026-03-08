package event

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"time"

	"gorm.io/gorm"
)

// EventType 事件类型
type EventType string

const (
	EventTypeFriendRequest      EventType = "friend_request"
	EventTypeFriendAccepted     EventType = "friend_accepted"
	EventTypeFriendRejected     EventType = "friend_rejected"
	EventTypeJoinRequest        EventType = "join_request"
	EventTypeJoinApproved       EventType = "join_approved"
	EventTypeJoinRejected       EventType = "join_rejected"
	EventTypeOrgInvitation      EventType = "org_invitation"
	EventTypeChatMessage        EventType = "chat_message"
	EventTypeSystemNotification EventType = "system_notification"
)

// EventStatus 事件状态
type EventStatus string

const (
	EventStatusPending   EventStatus = "pending"
	EventStatusDelivered EventStatus = "delivered"
	EventStatusRead      EventStatus = "read"
	EventStatusExpired   EventStatus = "expired"
)

// Event 统一事件/通知实体
type Event struct {
	ID           string      `gorm:"primaryKey;type:varchar(30)" json:"id"`
	Type         EventType   `gorm:"type:varchar(30);not null;index" json:"type"`
	SenderType   string      `gorm:"type:varchar(20);not null" json:"sender_type"`   // user/agent/system
	SenderID     string      `gorm:"type:varchar(30);not null" json:"sender_id"`
	ReceiverType string      `gorm:"type:varchar(20);not null" json:"receiver_type"` // user/agent/conversation
	ReceiverID   string      `gorm:"type:varchar(30);not null;index" json:"receiver_id"`
	Payload      Payload     `gorm:"type:jsonb" json:"payload"`
	Status       EventStatus `gorm:"type:varchar(20);default:'pending';index" json:"status"`
	CreatedAt    time.Time   `json:"created_at"`
	UpdatedAt    time.Time   `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

// Payload 事件载荷（JSONB类型）
type Payload map[string]interface{}

// Value 实现 driver.Valuer 接口
func (p Payload) Value() (driver.Value, error) {
	if p == nil {
		return nil, nil
	}
	return json.Marshal(p)
}

// Scan 实现 sql.Scanner 接口
func (p *Payload) Scan(value interface{}) error {
	if value == nil {
		*p = nil
		return nil
	}
	bytes, ok := value.([]byte)
	if !ok {
		return errors.New("type assertion to []byte failed")
	}
	return json.Unmarshal(bytes, p)
}

func (Event) TableName() string {
	return "events"
}

// NewEvent 创建新事件
func NewEvent(eventType EventType, senderType, senderID, receiverType, receiverID string, payload Payload) *Event {
	return &Event{
		ID:           "", // 由调用者使用 idgen.Generate 设置
		Type:         eventType,
		SenderType:   senderType,
		SenderID:     senderID,
		ReceiverType: receiverType,
		ReceiverID:   receiverID,
		Payload:      payload,
		Status:       EventStatusPending,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}
}