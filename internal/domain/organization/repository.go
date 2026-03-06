package organization

import (
	"context"

	"gorm.io/gorm"
)

type Repository interface {
	Create(ctx context.Context, org *Organization) error
	GetByID(ctx context.Context, id string) (*Organization, error)
	Update(ctx context.Context, org *Organization) error
	Delete(ctx context.Context, id string) error

	// 成员管理
	AddMember(ctx context.Context, membership *OrgMembership) error
	GetMembers(ctx context.Context, orgID string) ([]OrgMembership, error)
	GetMemberRole(ctx context.Context, orgID, userID string) (string, error)
	UpdateMemberRole(ctx context.Context, orgID, userID, role string) error
	RemoveMember(ctx context.Context, orgID, userID string) error
	IsMember(ctx context.Context, orgID, userID string) (bool, error)

	// 邀请管理
	CreateInvitation(ctx context.Context, invitation *Invitation) error
	GetInvitationByID(ctx context.Context, id string) (*Invitation, error)
	GetPendingInvitations(ctx context.Context, email string) ([]Invitation, error)
	UpdateInvitationStatus(ctx context.Context, id, status string) error

	// 用户所属组织
	GetUserOrganizations(ctx context.Context, userID string) ([]Organization, error)
}

type repository struct {
	db *gorm.DB
}

func NewRepository(db *gorm.DB) Repository {
	return &repository{db: db}
}

func (r *repository) Create(ctx context.Context, org *Organization) error {
	return r.db.WithContext(ctx).Create(org).Error
}

func (r *repository) GetByID(ctx context.Context, id string) (*Organization, error) {
	var org Organization
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&org).Error
	if err != nil {
		return nil, err
	}
	return &org, nil
}

func (r *repository) Update(ctx context.Context, org *Organization) error {
	return r.db.WithContext(ctx).Save(org).Error
}

func (r *repository) Delete(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Delete(&Organization{}, "id = ?", id).Error
}

func (r *repository) AddMember(ctx context.Context, membership *OrgMembership) error {
	return r.db.WithContext(ctx).Create(membership).Error
}

func (r *repository) GetMembers(ctx context.Context, orgID string) ([]OrgMembership, error) {
	var members []OrgMembership
	err := r.db.WithContext(ctx).Where("org_id = ?", orgID).Find(&members).Error
	return members, err
}

func (r *repository) GetMemberRole(ctx context.Context, orgID, userID string) (string, error) {
	var membership OrgMembership
	err := r.db.WithContext(ctx).Where("org_id = ? AND user_id = ?", orgID, userID).First(&membership).Error
	if err != nil {
		return "", err
	}
	return membership.Role, nil
}

func (r *repository) UpdateMemberRole(ctx context.Context, orgID, userID, role string) error {
	return r.db.WithContext(ctx).Model(&OrgMembership{}).
		Where("org_id = ? AND user_id = ?", orgID, userID).
		Update("role", role).Error
}

func (r *repository) RemoveMember(ctx context.Context, orgID, userID string) error {
	return r.db.WithContext(ctx).Delete(&OrgMembership{}, "org_id = ? AND user_id = ?", orgID, userID).Error
}

func (r *repository) IsMember(ctx context.Context, orgID, userID string) (bool, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&OrgMembership{}).
		Where("org_id = ? AND user_id = ?", orgID, userID).
		Count(&count).Error
	return count > 0, err
}

func (r *repository) CreateInvitation(ctx context.Context, invitation *Invitation) error {
	return r.db.WithContext(ctx).Create(invitation).Error
}

func (r *repository) GetInvitationByID(ctx context.Context, id string) (*Invitation, error) {
	var invitation Invitation
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&invitation).Error
	if err != nil {
		return nil, err
	}
	return &invitation, nil
}

func (r *repository) GetPendingInvitations(ctx context.Context, email string) ([]Invitation, error) {
	var invitations []Invitation
	err := r.db.WithContext(ctx).Where("email = ? AND status = ?", email, "pending").Find(&invitations).Error
	return invitations, err
}

func (r *repository) UpdateInvitationStatus(ctx context.Context, id, status string) error {
	return r.db.WithContext(ctx).Model(&Invitation{}).
		Where("id = ?", id).
		Update("status", status).Error
}

func (r *repository) GetUserOrganizations(ctx context.Context, userID string) ([]Organization, error) {
	var orgs []Organization
	err := r.db.WithContext(ctx).
		Joins("JOIN org_memberships ON organizations.id = org_memberships.org_id").
		Where("org_memberships.user_id = ?", userID).
		Find(&orgs).Error
	return orgs, err
}