package agent

import (
	"time"

	"gorm.io/gorm"
)

// Agent Agent实体
type Agent struct {
	ID          string         `gorm:"primaryKey;type:varchar(36)" json:"id"`
	Name        string         `gorm:"type:varchar(100);not null" json:"name"`
	Description string         `gorm:"type:text" json:"description,omitempty"`
	Avatar      string         `gorm:"type:varchar(500)" json:"avatar,omitempty"`
	Skills      string         `gorm:"type:text" json:"skills"` // JSON array of skills
	Metadata    string         `gorm:"type:text" json:"metadata,omitempty"` // JSON metadata
	OwnerID     string         `gorm:"type:varchar(36);not null;index" json:"owner_id"`
	AccessToken string         `gorm:"type:varchar(100);not null" json:"-"`
	Status      string         `gorm:"type:varchar(20);default:'inactive'" json:"status"` // inactive, active, online, offline
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Agent) TableName() string {
	return "agents"
}

// AgentOrgMembership Agent-组织关系
type AgentOrgMembership struct {
	AgentID    string    `gorm:"primaryKey;type:varchar(36)" json:"agent_id"`
	OrgID      string    `gorm:"primaryKey;type:varchar(36)" json:"org_id"`
	Status     string    `gorm:"type:varchar(20);not null" json:"status"` // pending, approved, rejected
	ApprovedBy string    `gorm:"type:varchar(36)" json:"approved_by,omitempty"`
	JoinedAt   time.Time `json:"joined_at,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
}

func (AgentOrgMembership) TableName() string {
	return "agent_org_memberships"
}

// JoinRequest 加入申请
type JoinRequest struct {
	ID        string         `gorm:"primaryKey;type:varchar(36)" json:"id"`
	AgentID   string         `gorm:"type:varchar(36);not null;index" json:"agent_id"`
	OrgID     string         `gorm:"type:varchar(36);not null;index" json:"org_id"`
	Status    string         `gorm:"type:varchar(20);default:'pending'" json:"status"` // pending, approved, rejected
	Reason    string         `gorm:"type:text" json:"reason,omitempty"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (JoinRequest) TableName() string {
	return "join_requests"
}