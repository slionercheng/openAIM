package organization

import (
	"time"

	"gorm.io/gorm"
)

// Organization 组织实体
type Organization struct {
	ID          string         `gorm:"primaryKey;type:varchar(36)" json:"id"`
	Name        string         `gorm:"type:varchar(100);not null" json:"name"`
	Type        string         `gorm:"type:varchar(20);not null" json:"type"` // personal, team, enterprise
	Description string         `gorm:"type:text" json:"description,omitempty"`
	OwnerID     string         `gorm:"type:varchar(36);not null" json:"owner_id"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Organization) TableName() string {
	return "organizations"
}

// OrgMembership 用户-组织关系
type OrgMembership struct {
	OrgID     string    `gorm:"primaryKey;type:varchar(36)" json:"org_id"`
	UserID    string    `gorm:"primaryKey;type:varchar(36)" json:"user_id"`
	Role      string    `gorm:"type:varchar(20);not null" json:"role"` // owner, admin, member
	JoinedAt  time.Time `json:"joined_at"`
	CreatedAt time.Time `json:"created_at"`
}

func (OrgMembership) TableName() string {
	return "org_memberships"
}

// Invitation 邀请
type Invitation struct {
	ID         string    `gorm:"primaryKey;type:varchar(36)" json:"id"`
	OrgID      string    `gorm:"type:varchar(36);not null;index" json:"org_id"`
	Email      string    `gorm:"type:varchar(255);not null;index" json:"email"`
	Role       string    `gorm:"type:varchar(20);not null" json:"role"`
	Status     string    `gorm:"type:varchar(20);default:'pending'" json:"status"` // pending, accepted, rejected, expired
	InviterID  string    `gorm:"type:varchar(36);not null" json:"inviter_id"`
	ExpiresAt  time.Time `json:"expires_at"`
	CreatedAt  time.Time `json:"created_at"`
	AcceptedAt *time.Time `json:"accepted_at,omitempty"`
}

func (Invitation) TableName() string {
	return "invitations"
}