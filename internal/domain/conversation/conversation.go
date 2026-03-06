package conversation

import (
	"time"

	"gorm.io/gorm"
)

// Conversation 会话实体
type Conversation struct {
	ID        string         `gorm:"primaryKey;type:varchar(36)" json:"id"`
	OrgID     string         `gorm:"type:varchar(36);not null;index" json:"org_id"`
	Type      string         `gorm:"type:varchar(20);not null" json:"type"` // direct, group
	Name      string         `gorm:"type:varchar(100)" json:"name,omitempty"`
	CreatedBy string         `gorm:"type:varchar(36);not null" json:"created_by"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Conversation) TableName() string {
	return "conversations"
}

// Participant 参与者
type Participant struct {
	ConversationID  string    `gorm:"primaryKey;type:varchar(36)" json:"conversation_id"`
	ParticipantType string    `gorm:"primaryKey;type:varchar(20)" json:"participant_type"` // user, agent
	ParticipantID   string    `gorm:"primaryKey;type:varchar(36)" json:"participant_id"`
	JoinedAt        time.Time `json:"joined_at"`
}

func (Participant) TableName() string {
	return "participants"
}