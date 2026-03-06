package conversation

import (
	"context"

	"gorm.io/gorm"
)

type Repository interface {
	Create(ctx context.Context, conv *Conversation) error
	GetByID(ctx context.Context, id string) (*Conversation, error)
	Update(ctx context.Context, conv *Conversation) error
	Delete(ctx context.Context, id string) error
	GetByUserID(ctx context.Context, userID string) ([]Conversation, error)
	GetByOrgID(ctx context.Context, orgID string) ([]Conversation, error)

	// 参与者管理
	AddParticipant(ctx context.Context, participant *Participant) error
	GetParticipants(ctx context.Context, conversationID string) ([]Participant, error)
	RemoveParticipant(ctx context.Context, conversationID, participantType, participantID string) error
	IsParticipant(ctx context.Context, conversationID, participantType, participantID string) (bool, error)

	// 获取用户参与的会话
	GetUserConversations(ctx context.Context, userID string) ([]Conversation, error)
}

type repository struct {
	db *gorm.DB
}

func NewRepository(db *gorm.DB) Repository {
	return &repository{db: db}
}

func (r *repository) Create(ctx context.Context, conv *Conversation) error {
	return r.db.WithContext(ctx).Create(conv).Error
}

func (r *repository) GetByID(ctx context.Context, id string) (*Conversation, error) {
	var conv Conversation
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&conv).Error
	if err != nil {
		return nil, err
	}
	return &conv, nil
}

func (r *repository) Update(ctx context.Context, conv *Conversation) error {
	return r.db.WithContext(ctx).Save(conv).Error
}

func (r *repository) Delete(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Delete(&Conversation{}, "id = ?", id).Error
}

func (r *repository) GetByUserID(ctx context.Context, userID string) ([]Conversation, error) {
	var convs []Conversation
	err := r.db.WithContext(ctx).
		Joins("JOIN participants ON conversations.id = participants.conversation_id").
		Where("participants.participant_type = ? AND participants.participant_id = ?", "user", userID).
		Find(&convs).Error
	return convs, err
}

func (r *repository) GetByOrgID(ctx context.Context, orgID string) ([]Conversation, error) {
	var convs []Conversation
	err := r.db.WithContext(ctx).Where("org_id = ?", orgID).Find(&convs).Error
	return convs, err
}

func (r *repository) AddParticipant(ctx context.Context, participant *Participant) error {
	return r.db.WithContext(ctx).Create(participant).Error
}

func (r *repository) GetParticipants(ctx context.Context, conversationID string) ([]Participant, error) {
	var participants []Participant
	err := r.db.WithContext(ctx).Where("conversation_id = ?", conversationID).Find(&participants).Error
	return participants, err
}

func (r *repository) RemoveParticipant(ctx context.Context, conversationID, participantType, participantID string) error {
	return r.db.WithContext(ctx).Delete(&Participant{},
		"conversation_id = ? AND participant_type = ? AND participant_id = ?",
		conversationID, participantType, participantID).Error
}

func (r *repository) IsParticipant(ctx context.Context, conversationID, participantType, participantID string) (bool, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&Participant{}).
		Where("conversation_id = ? AND participant_type = ? AND participant_id = ?",
			conversationID, participantType, participantID).
		Count(&count).Error
	return count > 0, err
}

func (r *repository) GetUserConversations(ctx context.Context, userID string) ([]Conversation, error) {
	var convs []Conversation
	err := r.db.WithContext(ctx).
		Joins("JOIN participants ON conversations.id = participants.conversation_id").
		Where("participants.participant_type = ? AND participants.participant_id = ?", "user", userID).
		Order("conversations.updated_at DESC").
		Find(&convs).Error
	return convs, err
}