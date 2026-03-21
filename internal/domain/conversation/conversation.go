package conversation

import (
	"time"

	"gorm.io/gorm"
)

// Conversation 会话实体
type Conversation struct {
	ID        string         `gorm:"primaryKey;type:varchar(36)" json:"id"`
	OrgID     string         `gorm:"type:varchar(36);index" json:"org_id"`
	Type      string         `gorm:"type:varchar(20);not null" json:"type"` // direct, group
	Name      string         `gorm:"type:varchar(100)" json:"name,omitempty"`
	IsPublic  bool           `gorm:"default:false" json:"is_public"`         // 群聊是否公开可搜索
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
	Role            string    `gorm:"type:varchar(20);default:member" json:"role"`         // owner, admin, member
	IsMuted         bool      `gorm:"default:false" json:"is_muted"`                       // 是否被禁言
	MutedUntil      *time.Time `json:"muted_until"`                                        // 禁言到期时间
	JoinedAt        time.Time `json:"joined_at"`
}

func (Participant) TableName() string {
	return "participants"
}

// ParticipantRole 参与者角色
const (
	RoleOwner  = "owner"
	RoleAdmin  = "admin"
	RoleMember = "member"
)

// JoinRequest 群聊加入请求
type JoinRequest struct {
	ID             string         `gorm:"primaryKey;type:varchar(36)" json:"id"`
	ConversationID string         `gorm:"type:varchar(36);not null;index" json:"conversation_id"`
	UserID         string         `gorm:"type:varchar(36);not null;index" json:"user_id"`
	Status         string         `gorm:"type:varchar(20);not null;default:pending" json:"status"` // pending, accepted, rejected
	Message        string         `gorm:"type:varchar(500)" json:"message"`                        // 申请消息
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}

func (JoinRequest) TableName() string {
	return "join_requests"
}

// JoinRequestStatus 加入请求状态
const (
	JoinStatusPending  = "pending"
	JoinStatusAccepted = "accepted"
	JoinStatusRejected = "rejected"
)

// Invitation 邀请成员
type Invitation struct {
	ID             string         `gorm:"primaryKey;type:varchar(36)" json:"id"`
	ConversationID string         `gorm:"type:varchar(36);not null;index" json:"conversation_id"`
	InviterID      string         `gorm:"type:varchar(36);not null" json:"inviter_id"`      // 邀请人
	InviteeID      string         `gorm:"type:varchar(36);not null;index" json:"invitee_id"` // 被邀请人
	Status         string         `gorm:"type:varchar(20);default:pending" json:"status"`   // pending, approved, rejected
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Invitation) TableName() string {
	return "invitations"
}

// InvitationStatus 邀请状态
const (
	InvitationStatusPending   = "pending"
	InvitationStatusApproved  = "approved"
	InvitationStatusRejected  = "rejected"
)