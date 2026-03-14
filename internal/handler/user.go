package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/your-org/openim/internal/domain/organization"
	"github.com/your-org/openim/internal/domain/user"
	"github.com/your-org/openim/internal/ws"
	"github.com/your-org/openim/pkg/jwt"
	"github.com/your-org/openim/pkg/response"
	"gorm.io/gorm"
)

type UserHandler struct {
	db       *gorm.DB
	userRepo user.Repository
	orgRepo  organization.Repository
	hub      *ws.Hub
}

func NewUserHandler(db *gorm.DB) *UserHandler {
	return &UserHandler{
		db:       db,
		userRepo: user.NewRepository(db),
		orgRepo:  organization.NewRepository(db),
	}
}

// SetHub 设置 Hub（用于在线状态检查）
func (h *UserHandler) SetHub(hub *ws.Hub) {
	h.hub = hub
}

// GetCurrentUser 获取当前用户信息
func (h *UserHandler) GetCurrentUser(c *gin.Context) {
	claims, exists := c.Get("claims")
	if !exists {
		response.Unauthorized(c, "未授权")
		return
	}

	userClaims := claims.(*jwt.Claims)
	u, err := h.userRepo.GetByID(c.Request.Context(), userClaims.UserID)
	if err != nil {
		response.NotFound(c, "用户不存在")
		return
	}

	response.Success(c, gin.H{
		"id":         u.ID,
		"email":      u.Email,
		"name":       u.Name,
		"avatar":     u.Avatar,
		"status":     u.Status,
		"created_at": u.CreatedAt,
	})
}

// UpdateUser 更新用户信息
func (h *UserHandler) UpdateUser(c *gin.Context) {
	claims := c.MustGet("claims").(*jwt.Claims)

	var req struct {
		Name   string `json:"name"`
		Avatar string `json:"avatar"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	u, err := h.userRepo.GetByID(c.Request.Context(), claims.UserID)
	if err != nil {
		response.NotFound(c, "用户不存在")
		return
	}

	if req.Name != "" {
		u.Name = req.Name
	}
	if req.Avatar != "" {
		u.Avatar = req.Avatar
	}

	if err := h.userRepo.Update(c.Request.Context(), u); err != nil {
		response.InternalError(c, "更新失败")
		return
	}

	response.Success(c, gin.H{
		"id":     u.ID,
		"name":   u.Name,
		"avatar": u.Avatar,
	})
}

// GetUserOrganizations 获取用户所属组织
func (h *UserHandler) GetUserOrganizations(c *gin.Context) {
	claims := c.MustGet("claims").(*jwt.Claims)

	orgs, err := h.orgRepo.GetUserOrganizations(c.Request.Context(), claims.UserID)
	if err != nil {
		response.InternalError(c, "获取组织列表失败")
		return
	}

	result := make([]gin.H, len(orgs))
	for i, org := range orgs {
		result[i] = gin.H{
			"id":          org.ID,
			"name":        org.Name,
			"type":        org.Type,
			"description": org.Description,
		}
	}

	response.Success(c, result)
}

// GetUserAgents 获取用户的Agent列表
func (h *UserHandler) GetUserAgents(c *gin.Context) {
	claims := c.MustGet("claims").(*jwt.Claims)

	var agents []struct {
		ID          string `json:"id"`
		Name        string `json:"name"`
		Description string `json:"description"`
		Status      string `json:"status"`
	}

	if err := h.db.Table("agents").
		Where("owner_id = ?", claims.UserID).
		Select("id, name, description, status").
		Find(&agents).Error; err != nil {
		response.InternalError(c, "获取Agent列表失败")
		return
	}

	response.Success(c, agents)
}

// GetUserOnlineStatus 获取用户在线状态
// GET /api/v1/users/:id/online
func (h *UserHandler) GetUserOnlineStatus(c *gin.Context) {
	userID := c.Param("id")

	online := false
	if h.hub != nil {
		online = h.hub.IsUserOnline(userID)
	}

	response.Success(c, gin.H{
		"user_id": userID,
		"online":  online,
	})
}

// GetUsersOnlineStatus 批量获取用户在线状态
// POST /api/v1/users/online-status
func (h *UserHandler) GetUsersOnlineStatus(c *gin.Context) {
	var req struct {
		UserIDs []string `json:"user_ids" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	statuses := make(map[string]bool)
	if h.hub != nil {
		for _, userID := range req.UserIDs {
			statuses[userID] = h.hub.IsUserOnline(userID)
		}
	} else {
		for _, userID := range req.UserIDs {
			statuses[userID] = false
		}
	}

	response.Success(c, statuses)
}