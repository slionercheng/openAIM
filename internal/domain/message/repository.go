package message

import (
	"context"

	"gorm.io/gorm"
)

type Repository interface {
	Create(ctx context.Context, message *Message) error
	GetByID(ctx context.Context, id string) (*Message, error)
	GetByConversationID(ctx context.Context, conversationID string, limit, offset int) ([]Message, int64, error)
	Delete(ctx context.Context, id string) error
}

type repository struct {
	db *gorm.DB
}

func NewRepository(db *gorm.DB) Repository {
	return &repository{db: db}
}

func (r *repository) Create(ctx context.Context, message *Message) error {
	return r.db.WithContext(ctx).Create(message).Error
}

func (r *repository) GetByID(ctx context.Context, id string) (*Message, error) {
	var message Message
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&message).Error
	if err != nil {
		return nil, err
	}
	return &message, nil
}

func (r *repository) GetByConversationID(ctx context.Context, conversationID string, limit, offset int) ([]Message, int64, error) {
	var messages []Message
	var total int64

	db := r.db.WithContext(ctx).Model(&Message{}).Where("conversation_id = ?", conversationID)
	if err := db.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	err := db.Order("created_at DESC").Limit(limit).Offset(offset).Find(&messages).Error
	return messages, total, err
}

func (r *repository) Delete(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Delete(&Message{}, "id = ?", id).Error
}