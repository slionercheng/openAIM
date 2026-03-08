package friendship

import (
	"context"

	"gorm.io/gorm"
)

// Repository 好友关系仓储接口
type Repository interface {
	// Create 创建好友关系
	Create(ctx context.Context, friendship *Friendship) error

	// GetByID 根据ID获取好友关系
	GetByID(ctx context.Context, id string) (*Friendship, error)

	// Update 更新好友关系
	Update(ctx context.Context, friendship *Friendship) error

	// Delete 删除好友关系（软删除）
	Delete(ctx context.Context, id string) error

	// GetByUserPair 根据两个用户ID获取好友关系（双向查询）
	GetByUserPair(ctx context.Context, userID1, userID2 string) (*Friendship, error)

	// GetFriends 获取用户的好友列表
	GetFriends(ctx context.Context, userID string, page, pageSize int) ([]Friendship, int64, error)

	// GetFriendRequests 获取收到的好友请求列表
	GetFriendRequests(ctx context.Context, userID string, status FriendshipStatus, page, pageSize int) ([]Friendship, int64, error)

	// GetSentRequests 获取发送的好友请求列表
	GetSentRequests(ctx context.Context, userID string, page, pageSize int) ([]Friendship, int64, error)

	// GetFriendshipStatus 获取与指定用户的好友关系状态
	GetFriendshipStatus(ctx context.Context, currentUserID, targetUserID string) (string, error)

	// IsFriend 检查两个用户是否是好友
	IsFriend(ctx context.Context, userID1, userID2 string) (bool, error)

	// CountPendingRequests 统计待处理的好友请求数量
	CountPendingRequests(ctx context.Context, userID string) (int64, error)
}

type repository struct {
	db *gorm.DB
}

// NewRepository 创建好友关系仓储
func NewRepository(db *gorm.DB) Repository {
	return &repository{db: db}
}

func (r *repository) Create(ctx context.Context, friendship *Friendship) error {
	return r.db.WithContext(ctx).Create(friendship).Error
}

func (r *repository) GetByID(ctx context.Context, id string) (*Friendship, error) {
	var friendship Friendship
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&friendship).Error
	if err != nil {
		return nil, err
	}
	return &friendship, nil
}

func (r *repository) Update(ctx context.Context, friendship *Friendship) error {
	return r.db.WithContext(ctx).Save(friendship).Error
}

func (r *repository) Delete(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Delete(&Friendship{}, "id = ?", id).Error
}

func (r *repository) GetByUserPair(ctx context.Context, userID1, userID2 string) (*Friendship, error) {
	var friendship Friendship
	err := r.db.WithContext(ctx).
		Where("(requester_id = ? AND addressee_id = ?) OR (requester_id = ? AND addressee_id = ?)",
			userID1, userID2, userID2, userID1).
		First(&friendship).Error
	if err != nil {
		return nil, err
	}
	return &friendship, nil
}

func (r *repository) GetFriends(ctx context.Context, userID string, page, pageSize int) ([]Friendship, int64, error) {
	var friendships []Friendship
	var total int64

	query := r.db.WithContext(ctx).Model(&Friendship{}).
		Where("(requester_id = ? OR addressee_id = ?) AND status = ?", userID, userID, FriendshipStatusAccepted)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := query.Order("updated_at DESC").Offset(offset).Limit(pageSize).Find(&friendships).Error; err != nil {
		return nil, 0, err
	}

	return friendships, total, nil
}

func (r *repository) GetFriendRequests(ctx context.Context, userID string, status FriendshipStatus, page, pageSize int) ([]Friendship, int64, error) {
	var friendships []Friendship
	var total int64

	query := r.db.WithContext(ctx).Model(&Friendship{}).
		Where("addressee_id = ?", userID)

	if status != "" {
		query = query.Where("status = ?", status)
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := query.Order("created_at DESC").Offset(offset).Limit(pageSize).Find(&friendships).Error; err != nil {
		return nil, 0, err
	}

	return friendships, total, nil
}

func (r *repository) GetSentRequests(ctx context.Context, userID string, page, pageSize int) ([]Friendship, int64, error) {
	var friendships []Friendship
	var total int64

	query := r.db.WithContext(ctx).Model(&Friendship{}).
		Where("requester_id = ? AND status = ?", userID, FriendshipStatusPending)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := query.Order("created_at DESC").Offset(offset).Limit(pageSize).Find(&friendships).Error; err != nil {
		return nil, 0, err
	}

	return friendships, total, nil
}

func (r *repository) GetFriendshipStatus(ctx context.Context, currentUserID, targetUserID string) (string, error) {
	friendship, err := r.GetByUserPair(ctx, currentUserID, targetUserID)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return "none", nil
		}
		return "", err
	}

	// 根据关系方向和状态返回对应的状态
	switch friendship.Status {
	case FriendshipStatusPending:
		if friendship.RequesterID == currentUserID {
			return "pending_sent", nil
		}
		return "pending_received", nil
	case FriendshipStatusAccepted:
		return "accepted", nil
	case FriendshipStatusRejected:
		return "rejected", nil
	case FriendshipStatusBlocked:
		if friendship.AddresseeID == currentUserID {
			return "blocked_by_me", nil
		}
		return "blocked", nil
	default:
		return "none", nil
	}
}

func (r *repository) IsFriend(ctx context.Context, userID1, userID2 string) (bool, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&Friendship{}).
		Where("((requester_id = ? AND addressee_id = ?) OR (requester_id = ? AND addressee_id = ?)) AND status = ?",
			userID1, userID2, userID2, userID1, FriendshipStatusAccepted).
		Count(&count).Error
	return count > 0, err
}

func (r *repository) CountPendingRequests(ctx context.Context, userID string) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&Friendship{}).
		Where("addressee_id = ? AND status = ?", userID, FriendshipStatusPending).
		Count(&count).Error
	return count, err
}