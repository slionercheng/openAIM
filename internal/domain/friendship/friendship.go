package friendship

import (
	"time"

	"gorm.io/gorm"
)

// FriendshipStatus 好友关系状态
type FriendshipStatus string

const (
	FriendshipStatusPending   FriendshipStatus = "pending"   // 待处理
	FriendshipStatusAccepted  FriendshipStatus = "accepted"  // 已接受
	FriendshipStatusRejected  FriendshipStatus = "rejected"  // 已拒绝
	FriendshipStatusBlocked   FriendshipStatus = "blocked"   // 已拉黑
)

// Friendship 好友关系实体
type Friendship struct {
	ID          string           `gorm:"primaryKey;type:varchar(36)" json:"id"`
	RequesterID string           `gorm:"type:varchar(36);not null;uniqueIndex:idx_friendship_pair" json:"requester_id"`
	AddresseeID string           `gorm:"type:varchar(36);not null;uniqueIndex:idx_friendship_pair" json:"addressee_id"`
	Status      FriendshipStatus `gorm:"type:varchar(20);not null;default:'pending'" json:"status"`
	CreatedAt   time.Time        `json:"created_at"`
	UpdatedAt   time.Time        `json:"updated_at"`
	DeletedAt   gorm.DeletedAt   `gorm:"index" json:"-"`

	// 关联
	Requester   *UserBrief       `gorm:"-" json:"requester,omitempty"`
	Addressee   *UserBrief       `gorm:"-" json:"addressee,omitempty"`
}

// UserBrief 用户简要信息（用于关联展示）
type UserBrief struct {
	ID     string `json:"id"`
	Email  string `json:"email"`
	Name   string `json:"name"`
	Avatar string `json:"avatar,omitempty"`
	Status string `json:"status,omitempty"`
}

func (Friendship) TableName() string {
	return "friendships"
}