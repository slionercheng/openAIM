package message

import (
	"time"

	"gorm.io/gorm"
)

// Message 消息实体
type Message struct {
	ID             string         `gorm:"primaryKey;type:varchar(36)" json:"id"`
	ConversationID string         `gorm:"type:varchar(36);not null;index" json:"conversation_id"`
	SenderType     string         `gorm:"type:varchar(20);not null" json:"sender_type"` // user, agent, system
	SenderID       string         `gorm:"type:varchar(36);not null" json:"sender_id"`
	Content        string         `gorm:"type:text;not null" json:"content"`
	ContentType    string         `gorm:"type:varchar(20);default:'text'" json:"content_type"` // text, markdown, json, system, invite_request
	Mentions       string         `gorm:"type:text" json:"mentions,omitempty"`                // JSON array of mentioned participants
	Metadata       string         `gorm:"type:text" json:"metadata,omitempty"`                // JSON object for additional data (e.g., invite request info)
	CreatedAt      time.Time      `json:"created_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Message) TableName() string {
	return "messages"
}