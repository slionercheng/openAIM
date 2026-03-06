package agent

import (
	"context"

	"gorm.io/gorm"
)

type Repository interface {
	Create(ctx context.Context, agent *Agent) error
	GetByID(ctx context.Context, id string) (*Agent, error)
	GetByAccessToken(ctx context.Context, token string) (*Agent, error)
	Update(ctx context.Context, agent *Agent) error
	Delete(ctx context.Context, id string) error
	GetByOwnerID(ctx context.Context, ownerID string) ([]Agent, error)

	// 组织关系
	AddToOrg(ctx context.Context, membership *AgentOrgMembership) error
	GetOrgMembership(ctx context.Context, agentID, orgID string) (*AgentOrgMembership, error)
	UpdateOrgMembershipStatus(ctx context.Context, agentID, orgID, status, approvedBy string) error
	GetAgentsByOrgID(ctx context.Context, orgID string) ([]Agent, error)
	IsInOrg(ctx context.Context, agentID, orgID string) (bool, error)

	// 加入申请
	CreateJoinRequest(ctx context.Context, request *JoinRequest) error
	GetJoinRequestByID(ctx context.Context, id string) (*JoinRequest, error)
	GetJoinRequestsByAgent(ctx context.Context, agentID string) ([]JoinRequest, error)
	GetPendingJoinRequestsByOrg(ctx context.Context, orgID string) ([]JoinRequest, error)
	UpdateJoinRequestStatus(ctx context.Context, id, status string) error
}

type repository struct {
	db *gorm.DB
}

func NewRepository(db *gorm.DB) Repository {
	return &repository{db: db}
}

func (r *repository) Create(ctx context.Context, agent *Agent) error {
	return r.db.WithContext(ctx).Create(agent).Error
}

func (r *repository) GetByID(ctx context.Context, id string) (*Agent, error) {
	var agent Agent
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&agent).Error
	if err != nil {
		return nil, err
	}
	return &agent, nil
}

func (r *repository) GetByAccessToken(ctx context.Context, token string) (*Agent, error) {
	var agent Agent
	err := r.db.WithContext(ctx).Where("access_token = ?", token).First(&agent).Error
	if err != nil {
		return nil, err
	}
	return &agent, nil
}

func (r *repository) Update(ctx context.Context, agent *Agent) error {
	return r.db.WithContext(ctx).Save(agent).Error
}

func (r *repository) Delete(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Delete(&Agent{}, "id = ?", id).Error
}

func (r *repository) GetByOwnerID(ctx context.Context, ownerID string) ([]Agent, error) {
	var agents []Agent
	err := r.db.WithContext(ctx).Where("owner_id = ?", ownerID).Find(&agents).Error
	return agents, err
}

func (r *repository) AddToOrg(ctx context.Context, membership *AgentOrgMembership) error {
	return r.db.WithContext(ctx).Create(membership).Error
}

func (r *repository) GetOrgMembership(ctx context.Context, agentID, orgID string) (*AgentOrgMembership, error) {
	var membership AgentOrgMembership
	err := r.db.WithContext(ctx).Where("agent_id = ? AND org_id = ?", agentID, orgID).First(&membership).Error
	if err != nil {
		return nil, err
	}
	return &membership, nil
}

func (r *repository) UpdateOrgMembershipStatus(ctx context.Context, agentID, orgID, status, approvedBy string) error {
	updates := map[string]interface{}{
		"status":      status,
		"approved_by": approvedBy,
		"joined_at":   gorm.Expr("NOW()"),
	}
	return r.db.WithContext(ctx).Model(&AgentOrgMembership{}).
		Where("agent_id = ? AND org_id = ?", agentID, orgID).
		Updates(updates).Error
}

func (r *repository) GetAgentsByOrgID(ctx context.Context, orgID string) ([]Agent, error) {
	var agents []Agent
	err := r.db.WithContext(ctx).
		Joins("JOIN agent_org_memberships ON agents.id = agent_org_memberships.agent_id").
		Where("agent_org_memberships.org_id = ? AND agent_org_memberships.status = ?", orgID, "approved").
		Find(&agents).Error
	return agents, err
}

func (r *repository) IsInOrg(ctx context.Context, agentID, orgID string) (bool, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&AgentOrgMembership{}).
		Where("agent_id = ? AND org_id = ? AND status = ?", agentID, orgID, "approved").
		Count(&count).Error
	return count > 0, err
}

func (r *repository) CreateJoinRequest(ctx context.Context, request *JoinRequest) error {
	return r.db.WithContext(ctx).Create(request).Error
}

func (r *repository) GetJoinRequestByID(ctx context.Context, id string) (*JoinRequest, error) {
	var request JoinRequest
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&request).Error
	if err != nil {
		return nil, err
	}
	return &request, nil
}

func (r *repository) GetJoinRequestsByAgent(ctx context.Context, agentID string) ([]JoinRequest, error) {
	var requests []JoinRequest
	err := r.db.WithContext(ctx).Where("agent_id = ?", agentID).Order("created_at DESC").Find(&requests).Error
	return requests, err
}

func (r *repository) GetPendingJoinRequestsByOrg(ctx context.Context, orgID string) ([]JoinRequest, error) {
	var requests []JoinRequest
	err := r.db.WithContext(ctx).Where("org_id = ? AND status = ?", orgID, "pending").Order("created_at DESC").Find(&requests).Error
	return requests, err
}

func (r *repository) UpdateJoinRequestStatus(ctx context.Context, id, status string) error {
	return r.db.WithContext(ctx).Model(&JoinRequest{}).
		Where("id = ?", id).
		Update("status", status).Error
}