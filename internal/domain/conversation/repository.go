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
	GetParticipant(ctx context.Context, conversationID, participantType, participantID string) (*Participant, error)
	UpdateParticipant(ctx context.Context, participant *Participant) error
	RemoveParticipant(ctx context.Context, conversationID, participantType, participantID string) error
	IsParticipant(ctx context.Context, conversationID, participantType, participantID string) (bool, error)
	IsOwnerOrAdmin(ctx context.Context, conversationID, userID string) (bool, error)
	GetAdmins(ctx context.Context, conversationID string) ([]Participant, error) // 获取所有管理员和群主

	// 获取用户参与的会话
	GetUserConversations(ctx context.Context, userID string) ([]Conversation, error)

	// 查找两个用户之间的私聊会话
	FindDirectConversation(ctx context.Context, userID1, userID2 string) (*Conversation, error)

	// 搜索公开群聊
	SearchPublicGroups(ctx context.Context, query string, limit int) ([]Conversation, error)

	// 加入请求管理
	CreateJoinRequest(ctx context.Context, req *JoinRequest) error
	GetJoinRequest(ctx context.Context, id string) (*JoinRequest, error)
	GetPendingJoinRequests(ctx context.Context, conversationID string) ([]JoinRequest, error)
	GetUserJoinRequest(ctx context.Context, conversationID, userID string) (*JoinRequest, error)
	UpdateJoinRequest(ctx context.Context, req *JoinRequest) error

	// 邀请管理
	CreateInvitation(ctx context.Context, inv *Invitation) error
	GetInvitation(ctx context.Context, id string) (*Invitation, error)
	GetPendingInvitations(ctx context.Context, conversationID string) ([]Invitation, error)
	GetUserInvitation(ctx context.Context, conversationID, inviteeID string) (*Invitation, error)
	GetUserPendingInvitations(ctx context.Context, inviteeID string) ([]Invitation, error) // 获取用户收到的所有待处理邀请
	UpdateInvitation(ctx context.Context, inv *Invitation) error
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

// FindDirectConversation 查找两个用户之间的私聊会话
func (r *repository) FindDirectConversation(ctx context.Context, userID1, userID2 string) (*Conversation, error) {
	var conv Conversation

	// 查找私聊会话，其中两个用户都是参与者
	err := r.db.WithContext(ctx).
		Select("conversations.*").
		Joins("JOIN participants p1 ON conversations.id = p1.conversation_id").
		Joins("JOIN participants p2 ON conversations.id = p2.conversation_id").
		Where("conversations.type = ?", "direct").
		Where("p1.participant_type = ? AND p1.participant_id = ?", "user", userID1).
		Where("p2.participant_type = ? AND p2.participant_id = ?", "user", userID2).
		First(&conv).Error

	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}
		return nil, err
	}
	return &conv, nil
}

// SearchPublicGroups 搜索公开群聊
func (r *repository) SearchPublicGroups(ctx context.Context, query string, limit int) ([]Conversation, error) {
	var convs []Conversation
	db := r.db.WithContext(ctx).
		Where("type = ? AND is_public = ?", "group", true)

	if query != "" {
		db = db.Where("name ILIKE ?", "%"+query+"%")
	}

	if limit > 0 {
		db = db.Limit(limit)
	}

	err := db.Order("created_at DESC").Find(&convs).Error
	return convs, err
}

// CreateJoinRequest 创建加入请求
func (r *repository) CreateJoinRequest(ctx context.Context, req *JoinRequest) error {
	return r.db.WithContext(ctx).Create(req).Error
}

// GetJoinRequest 获取加入请求
func (r *repository) GetJoinRequest(ctx context.Context, id string) (*JoinRequest, error) {
	var req JoinRequest
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&req).Error
	if err != nil {
		return nil, err
	}
	return &req, nil
}

// GetPendingJoinRequests 获取待处理的加入请求
func (r *repository) GetPendingJoinRequests(ctx context.Context, conversationID string) ([]JoinRequest, error) {
	var requests []JoinRequest
	err := r.db.WithContext(ctx).
		Where("conversation_id = ? AND status = ?", conversationID, JoinStatusPending).
		Order("created_at DESC").
		Find(&requests).Error
	return requests, err
}

// GetUserJoinRequest 获取用户的加入请求
func (r *repository) GetUserJoinRequest(ctx context.Context, conversationID, userID string) (*JoinRequest, error) {
	var req JoinRequest
	err := r.db.WithContext(ctx).
		Where("conversation_id = ? AND user_id = ?", conversationID, userID).
		Order("created_at DESC").
		First(&req).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}
		return nil, err
	}
	return &req, nil
}

// UpdateJoinRequest 更新加入请求
func (r *repository) UpdateJoinRequest(ctx context.Context, req *JoinRequest) error {
	return r.db.WithContext(ctx).Save(req).Error
}

// GetParticipant 获取单个参与者
func (r *repository) GetParticipant(ctx context.Context, conversationID, participantType, participantID string) (*Participant, error) {
	var p Participant
	err := r.db.WithContext(ctx).
		Where("conversation_id = ? AND participant_type = ? AND participant_id = ?",
			conversationID, participantType, participantID).
		First(&p).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}
		return nil, err
	}
	return &p, nil
}

// UpdateParticipant 更新参与者
func (r *repository) UpdateParticipant(ctx context.Context, participant *Participant) error {
	return r.db.WithContext(ctx).Save(participant).Error
}

// IsOwnerOrAdmin 检查用户是否是群主或管理员
func (r *repository) IsOwnerOrAdmin(ctx context.Context, conversationID, userID string) (bool, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&Participant{}).
		Where("conversation_id = ? AND participant_type = ? AND participant_id = ? AND role IN ?",
			conversationID, "user", userID, []string{RoleOwner, RoleAdmin}).
		Count(&count).Error
	return count > 0, err
}

// GetAdmins 获取群聊的所有管理员和群主
func (r *repository) GetAdmins(ctx context.Context, conversationID string) ([]Participant, error) {
	var admins []Participant
	err := r.db.WithContext(ctx).
		Where("conversation_id = ? AND participant_type = ? AND role IN ?",
			conversationID, "user", []string{RoleOwner, RoleAdmin}).
		Find(&admins).Error
	return admins, err
}

// CreateInvitation 创建邀请
func (r *repository) CreateInvitation(ctx context.Context, inv *Invitation) error {
	return r.db.WithContext(ctx).Create(inv).Error
}

// GetInvitation 获取邀请
func (r *repository) GetInvitation(ctx context.Context, id string) (*Invitation, error) {
	var inv Invitation
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&inv).Error
	if err != nil {
		return nil, err
	}
	return &inv, nil
}

// GetPendingInvitations 获取待处理的邀请
func (r *repository) GetPendingInvitations(ctx context.Context, conversationID string) ([]Invitation, error) {
	var invitations []Invitation
	err := r.db.WithContext(ctx).
		Where("conversation_id = ? AND status = ?", conversationID, InvitationStatusPending).
		Order("created_at DESC").
		Find(&invitations).Error
	return invitations, err
}

// GetUserInvitation 获取用户的邀请
func (r *repository) GetUserInvitation(ctx context.Context, conversationID, inviteeID string) (*Invitation, error) {
	var inv Invitation
	err := r.db.WithContext(ctx).
		Where("conversation_id = ? AND invitee_id = ?", conversationID, inviteeID).
		Order("created_at DESC").
		First(&inv).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}
		return nil, err
	}
	return &inv, nil
}

// UpdateInvitation 更新邀请
func (r *repository) UpdateInvitation(ctx context.Context, inv *Invitation) error {
	return r.db.WithContext(ctx).Save(inv).Error
}

// GetUserPendingInvitations 获取用户收到的所有待处理邀请
func (r *repository) GetUserPendingInvitations(ctx context.Context, inviteeID string) ([]Invitation, error) {
	var invitations []Invitation
	err := r.db.WithContext(ctx).
		Where("invitee_id = ? AND status = ?", inviteeID, InvitationStatusPending).
		Order("created_at DESC").
		Find(&invitations).Error
	return invitations, err
}