package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/your-org/openim/internal/domain/organization"
	"github.com/your-org/openim/pkg/jwt"
	"github.com/your-org/openim/pkg/response"
	"gorm.io/gorm"
)

type OrganizationHandler struct {
	db      *gorm.DB
	orgRepo organization.Repository
}

func NewOrganizationHandler(db *gorm.DB) *OrganizationHandler {
	return &OrganizationHandler{
		db:      db,
		orgRepo: organization.NewRepository(db),
	}
}

type CreateOrgRequest struct {
	Name        string `json:"name" binding:"required,min=2,max=100"`
	Type        string `json:"type" binding:"required,oneof=personal team enterprise"`
	Description string `json:"description"`
}

type InviteMemberRequest struct {
	Email string `json:"email" binding:"required,email"`
	Role  string `json:"role" binding:"required,oneof=admin member"`
}

// Create 创建组织
func (h *OrganizationHandler) Create(c *gin.Context) {
	var req CreateOrgRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误: "+err.Error())
		return
	}

	claims, _ := c.Get("claims").(*jwt.Claims)

	org := &organization.Organization{
		ID:          "org_" + uuid.New().String()[:8],
		Name:        req.Name,
		Type:        req.Type,
		Description: req.Description,
		OwnerID:     claims.UserID,
	}

	tx := h.db.Begin()

	if err := tx.Create(org).Error; err != nil {
		tx.Rollback()
		response.InternalError(c, "创建组织失败")
		return
	}

	// 创建者加入组织作为 owner
	membership := &organization.OrgMembership{
		OrgID:    org.ID,
		UserID:   claims.UserID,
		Role:     "owner",
		JoinedAt: time.Now(),
	}

	if err := tx.Create(membership).Error; err != nil {
		tx.Rollback()
		response.InternalError(c, "创建组织失败")
		return
	}

	tx.Commit()

	response.Success(c, gin.H{
		"id":           org.ID,
		"name":         org.Name,
		"type":         org.Type,
		"description":  org.Description,
		"owner_id":     org.OwnerID,
		"created_at":   org.CreatedAt,
		"member_count": 1,
	})
}

// GetByID 获取组织详情
func (h *OrganizationHandler) GetByID(c *gin.Context) {
	orgID := c.Param("id")
	claims, _ := c.Get("claims").(*jwt.Claims)

	// 验证用户是否在组织中
	isMember, err := h.orgRepo.IsMember(c.Request.Context(), orgID, claims.UserID)
	if err != nil || !isMember {
		response.Forbidden(c, "无权访问该组织")
		return
	}

	org, err := h.orgRepo.GetByID(c.Request.Context(), orgID)
	if err != nil {
		response.NotFound(c, "组织不存在")
		return
	}

	response.Success(c, gin.H{
		"id":          org.ID,
		"name":        org.Name,
		"type":        org.Type,
		"description": org.Description,
		"owner_id":    org.OwnerID,
		"created_at":  org.CreatedAt,
	})
}

// Update 更新组织信息
func (h *OrganizationHandler) Update(c *gin.Context) {
	orgID := c.Param("id")
	claims, _ := c.Get("claims").(*jwt.Claims)

	// 验证是否为管理员
	role, err := h.orgRepo.GetMemberRole(c.Request.Context(), orgID, claims.UserID)
	if err != nil || (role != "owner" && role != "admin") {
		response.Forbidden(c, "无权修改组织信息")
		return
	}

	var req struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	org, err := h.orgRepo.GetByID(c.Request.Context(), orgID)
	if err != nil {
		response.NotFound(c, "组织不存在")
		return
	}

	if req.Name != "" {
		org.Name = req.Name
	}
	if req.Description != "" {
		org.Description = req.Description
	}

	if err := h.orgRepo.Update(c.Request.Context(), org); err != nil {
		response.InternalError(c, "更新失败")
		return
	}

	response.Success(c, gin.H{
		"id":          org.ID,
		"name":        org.Name,
		"description": org.Description,
	})
}

// Delete 解散组织
func (h *OrganizationHandler) Delete(c *gin.Context) {
	orgID := c.Param("id")
	claims, _ := c.Get("claims").(*jwt.Claims)

	// 验证是否为 owner
	role, err := h.orgRepo.GetMemberRole(c.Request.Context(), orgID, claims.UserID)
	if err != nil || role != "owner" {
		response.Forbidden(c, "只有组织所有者可以解散组织")
		return
	}

	org, err := h.orgRepo.GetByID(c.Request.Context(), orgID)
	if err != nil {
		response.NotFound(c, "组织不存在")
		return
	}

	// 个人组织不能解散
	if org.Type == "personal" {
		response.BadRequest(c, 400002, "个人组织不能解散")
		return
	}

	if err := h.orgRepo.Delete(c.Request.Context(), orgID); err != nil {
		response.InternalError(c, "解散失败")
		return
	}

	response.Success(c, nil)
}

// GetMembers 获取组织成员
func (h *OrganizationHandler) GetMembers(c *gin.Context) {
	orgID := c.Param("id")
	claims, _ := c.Get("claims").(*jwt.Claims)

	// 验证用户是否在组织中
	isMember, err := h.orgRepo.IsMember(c.Request.Context(), orgID, claims.UserID)
	if err != nil || !isMember {
		response.Forbidden(c, "无权访问")
		return
	}

	members, err := h.orgRepo.GetMembers(c.Request.Context(), orgID)
	if err != nil {
		response.InternalError(c, "获取成员列表失败")
		return
	}

	// 获取用户详情
	var userIDs []string
	for _, m := range members {
		userIDs = append(userIDs, m.UserID)
	}

	var users []struct {
		ID     string `json:"id"`
		Name   string `json:"name"`
		Email  string `json:"email"`
		Avatar string `json:"avatar"`
	}
	h.db.Table("users").Where("id IN ?", userIDs).Find(&users)

	userMap := make(map[string]gin.H)
	for _, u := range users {
		userMap[u.ID] = gin.H{
			"id":     u.ID,
			"name":   u.Name,
			"email":  u.Email,
			"avatar": u.Avatar,
		}
	}

	result := make([]gin.H, 0)
	for _, m := range members {
		if u, ok := userMap[m.UserID]; ok {
			result = append(result, gin.H{
				"user":  u,
				"role":  m.Role,
				"joined_at": m.JoinedAt,
			})
		}
	}

	response.Success(c, result)
}

// InviteMember 邀请成员
func (h *OrganizationHandler) InviteMember(c *gin.Context) {
	orgID := c.Param("id")
	claims, _ := c.Get("claims").(*jwt.Claims)

	// 验证是否为管理员
	role, err := h.orgRepo.GetMemberRole(c.Request.Context(), orgID, claims.UserID)
	if err != nil || (role != "owner" && role != "admin") {
		response.Forbidden(c, "无权邀请成员")
		return
	}

	var req InviteMemberRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	invitation := &organization.Invitation{
		ID:        "inv_" + uuid.New().String()[:8],
		OrgID:     orgID,
		Email:     req.Email,
		Role:      req.Role,
		Status:    "pending",
		InviterID: claims.UserID,
		ExpiresAt: time.Now().Add(7 * 24 * time.Hour),
	}

	if err := h.orgRepo.CreateInvitation(c.Request.Context(), invitation); err != nil {
		response.InternalError(c, "创建邀请失败")
		return
	}

	response.Success(c, gin.H{
		"invitation_id": invitation.ID,
		"email":         invitation.Email,
		"org_id":        invitation.OrgID,
		"status":        invitation.Status,
		"expires_at":    invitation.ExpiresAt,
	})
}

// GetAgents 获取组织内的Agent
func (h *OrganizationHandler) GetAgents(c *gin.Context) {
	orgID := c.Param("id")
	claims, _ := c.Get("claims").(*jwt.Claims)

	// 验证用户是否在组织中
	isMember, err := h.orgRepo.IsMember(c.Request.Context(), orgID, claims.UserID)
	if err != nil || !isMember {
		response.Forbidden(c, "无权访问")
		return
	}

	var agents []struct {
		ID          string `json:"id"`
		Name        string `json:"name"`
		Description string `json:"description"`
		Avatar      string `json:"avatar"`
		Status      string `json:"status"`
		OwnerID     string `json:"owner_id"`
	}

	err = h.db.Table("agents").
		Joins("JOIN agent_org_memberships ON agents.id = agent_org_memberships.agent_id").
		Where("agent_org_memberships.org_id = ? AND agent_org_memberships.status = ?", orgID, "approved").
		Select("agents.id, agents.name, agents.description, agents.avatar, agents.status, agents.owner_id").
		Find(&agents).Error

	if err != nil {
		response.InternalError(c, "获取Agent列表失败")
		return
	}

	response.Success(c, agents)
}

// UpdateMemberRole 更新成员角色
func (h *OrganizationHandler) UpdateMemberRole(c *gin.Context) {
	orgID := c.Param("id")
	userID := c.Param("user_id")
	claims, _ := c.Get("claims").(*jwt.Claims)

	// 验证是否为 owner
	role, err := h.orgRepo.GetMemberRole(c.Request.Context(), orgID, claims.UserID)
	if err != nil || role != "owner" {
		response.Forbidden(c, "只有组织所有者可以修改成员角色")
		return
	}

	var req struct {
		Role string `json:"role" binding:"required,oneof=admin member"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	if err := h.orgRepo.UpdateMemberRole(c.Request.Context(), orgID, userID, req.Role); err != nil {
		response.InternalError(c, "更新失败")
		return
	}

	response.Success(c, nil)
}

// RemoveMember 移除成员
func (h *OrganizationHandler) RemoveMember(c *gin.Context) {
	orgID := c.Param("id")
	userID := c.Param("user_id")
	claims, _ := c.Get("claims").(*jwt.Claims)

	// 验证是否为管理员
	role, err := h.orgRepo.GetMemberRole(c.Request.Context(), orgID, claims.UserID)
	if err != nil || (role != "owner" && role != "admin") {
		response.Forbidden(c, "无权移除成员")
		return
	}

	// 不能移除 owner
	targetRole, _ := h.orgRepo.GetMemberRole(c.Request.Context(), orgID, userID)
	if targetRole == "owner" {
		response.BadRequest(c, 400003, "不能移除组织所有者")
		return
	}

	if err := h.orgRepo.RemoveMember(c.Request.Context(), orgID, userID); err != nil {
		response.InternalError(c, "移除失败")
		return
	}

	response.Success(c, nil)
}