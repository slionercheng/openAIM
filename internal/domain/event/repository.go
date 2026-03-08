package event

import (
	"context"

	"gorm.io/gorm"
)

// Repository 事件仓储接口
type Repository interface {
	// Create 创建事件
	Create(ctx context.Context, event *Event) error

	// GetByID 根据ID获取事件
	GetByID(ctx context.Context, id string) (*Event, error)

	// Update 更新事件
	Update(ctx context.Context, event *Event) error

	// Delete 删除事件
	Delete(ctx context.Context, id string) error

	// GetByReceiver 获取接收者的所有事件
	GetByReceiver(ctx context.Context, receiverType, receiverID string, page, pageSize int) ([]Event, int64, error)

	// GetPending 获取待处理的事件
	GetPending(ctx context.Context, receiverType, receiverID string) ([]Event, error)

	// GetByType 获取指定类型的事件
	GetByType(ctx context.Context, eventType EventType, receiverID string, page, pageSize int) ([]Event, int64, error)

	// MarkAsDelivered 标记为已送达
	MarkAsDelivered(ctx context.Context, id string) error

	// MarkAsRead 标记为已读
	MarkAsRead(ctx context.Context, id string) error

	// MarkAllAsRead 标记所有为已读
	MarkAllAsRead(ctx context.Context, receiverType, receiverID string) error

	// CountUnread 统计未读数量
	CountUnread(ctx context.Context, receiverType, receiverID string) (int64, error)
}

type repository struct {
	db *gorm.DB
}

// NewRepository 创建事件仓储
func NewRepository(db *gorm.DB) Repository {
	return &repository{db: db}
}

func (r *repository) Create(ctx context.Context, event *Event) error {
	return r.db.WithContext(ctx).Create(event).Error
}

func (r *repository) GetByID(ctx context.Context, id string) (*Event, error) {
	var event Event
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&event).Error
	if err != nil {
		return nil, err
	}
	return &event, nil
}

func (r *repository) Update(ctx context.Context, event *Event) error {
	return r.db.WithContext(ctx).Save(event).Error
}

func (r *repository) Delete(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Delete(&Event{}, "id = ?", id).Error
}

func (r *repository) GetByReceiver(ctx context.Context, receiverType, receiverID string, page, pageSize int) ([]Event, int64, error) {
	var events []Event
	var total int64

	query := r.db.WithContext(ctx).Model(&Event{}).
		Where("receiver_type = ? AND receiver_id = ?", receiverType, receiverID)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := query.Order("created_at DESC").Offset(offset).Limit(pageSize).Find(&events).Error; err != nil {
		return nil, 0, err
	}

	return events, total, nil
}

func (r *repository) GetPending(ctx context.Context, receiverType, receiverID string) ([]Event, error) {
	var events []Event
	err := r.db.WithContext(ctx).
		Where("receiver_type = ? AND receiver_id = ? AND status = ?", receiverType, receiverID, EventStatusPending).
		Order("created_at ASC").
		Find(&events).Error
	return events, err
}

func (r *repository) GetByType(ctx context.Context, eventType EventType, receiverID string, page, pageSize int) ([]Event, int64, error) {
	var events []Event
	var total int64

	query := r.db.WithContext(ctx).Model(&Event{}).
		Where("type = ? AND receiver_id = ?", eventType, receiverID)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := query.Order("created_at DESC").Offset(offset).Limit(pageSize).Find(&events).Error; err != nil {
		return nil, 0, err
	}

	return events, total, nil
}

func (r *repository) MarkAsDelivered(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Model(&Event{}).
		Where("id = ?", id).
		Update("status", EventStatusDelivered).Error
}

func (r *repository) MarkAsRead(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Model(&Event{}).
		Where("id = ?", id).
		Update("status", EventStatusRead).Error
}

func (r *repository) MarkAllAsRead(ctx context.Context, receiverType, receiverID string) error {
	return r.db.WithContext(ctx).Model(&Event{}).
		Where("receiver_type = ? AND receiver_id = ? AND status != ?", receiverType, receiverID, EventStatusRead).
		Update("status", EventStatusRead).Error
}

func (r *repository) CountUnread(ctx context.Context, receiverType, receiverID string) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&Event{}).
		Where("receiver_type = ? AND receiver_id = ? AND status != ?", receiverType, receiverID, EventStatusRead).
		Count(&count).Error
	return count, err
}