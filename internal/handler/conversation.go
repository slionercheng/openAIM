package handler

import (
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/your-org/openim/internal/domain/agent"
	"github.com/your-org/openim/internal/domain/conversation"
	"github.com/your-org/openim/internal/domain/organization"
	"github.com/your-org/openim/pkg/jwt"
	"github.com/your-org/openim/pkg/response"
	"gorm.io/gorm"
)

type ConversationHandler struct {
	db      *gorm.DB
	convRepo conversation.Repository
	orgRepo  organization.Repository
	agentRepo agent.Repository
}

func NewConversationHandler(db *gorm.DB) *ConversationHandler {
	return &ConversationHandler{
		db:       db,
		convRepo: conversation.NewRepository(db),
		orgRepo:  organization.NewRepository(db),
		agentRepo: agent.NewRepository(db),
	}
}

type CreateConversationRequest struct {
	OrgID          string `json:"org_id" binding:"required"`
	Type           string `json:"type" binding:"required,oneof=direct group"`
	Name           string `json:"name"`
	ParticipantIDs []struct {
		Type string `json:"type" binding:"required,oneof=user agent"`
		ID   string `json:"id" binding:"required"`
	} `json:"participant_ids" binding:"required,min=1"`
}

// Create 创建会话
func (h *ConversationHandler) Create(c *gin.Context) {
	var req CreateConversationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误: "+err.Error())
		return
	}

	claims, _ := c.Get("claims").(*jwt.Claims)

	// 验证用户是否在组织中
	isMember, err := h.orgRepo.IsMember(c.Request.Context(), req.OrgID, claims.UserID)
	if err != nil || !isMember {
		response.Forbidden(c, "无权在该组织创建会话")
		return
	}

	// 验证所有参与者
	for _, p := range req.ParticipantIDs {
		if p.Type == "user" {
			isParticipant, _ := h.orgRepo.IsMember(c.Request.Context(), req.OrgID, p.ID)
			if !isParticipant {
				response.BadRequest(c, 400002, "参与者 "+p.ID+" 不在该组织中")
				return
			}
		} else if p.Type == "agent" {
			isInOrg, _ := h.agentRepo.IsInOrg(c.Request.Context(), p.ID, req.OrgID)
			if !isInOrg {
				response.BadRequest(c, 400003, "Agent "+p.ID+" 不在该组织中")
				return
			}
		}
	}

	tx := h.db.Begin()

	conv := &conversation.Conversation{
		ID:        "conv_" + uuid.New().String()[:8],
		OrgID:     req.OrgID,
		Type:      req.Type,
		Name:      req.Name,
		CreatedBy: claims.UserID,
	}

	if err := h.convRepo.Create(c.Request.Context(), conv); err != nil {
		tx.Rollback()
		response.InternalError(c, "创建会话失败")
		return
	}

	// 添加创建者作为参与者
	creatorParticipant := &conversation.Participant{
		ConversationID:  conv.ID,
		ParticipantType: "user",
		ParticipantID:   claims.UserID,
		JoinedAt:        time.Now(),
	}
	if err := h.convRepo.AddParticipant(c.Request.Context(), creatorParticipant); err != nil {
		tx.Rollback()
		response.InternalError(c, "添加参与者失败")
		return
	}

	// 添加其他参与者
	participantMap := make(map[string]bool)
	participantMap[claims.UserID] = true

	for _, p := range req.ParticipantIDs {
		key := p.Type + "_" + p.ID
		if participantMap[key] {
			continue
		}
		participantMap[key] = true

		participant := &conversation.Participant{
			ConversationID:  conv.ID,
			ParticipantType: p.Type,
			ParticipantID:   p.ID,
			JoinedAt:        time.Now(),
		}
		if err := h.convRepo.AddParticipant(c.Request.Context(), participant); err != nil {
			tx.Rollback()
			response.InternalError(c, "添加参与者失败")
			return
		}
	}

	tx.Commit()

	// 获取参与者详情
	participants, _ := h.convRepo.GetParticipants(c.Request.Context(), conv.ID)
	participantDetails := make([]gin.H, len(participants))

	for i, p := range participants {
		if p.ParticipantType == "user" {
			var u struct {
				ID     string `json:"id"`
				Name   string `json:"name"`
				Avatar string `json:"avatar"`
			}
			h.db.Table("users").Where("id = ?", p.ParticipantID).First(&u)
			participantDetails[i] = gin.H{
				"type": "user",
				"id":   u.ID,
				"name": u.Name,
				"avatar": u.Avatar,
			}
		} else {
			var a struct {
				ID     string `json:"id"`
				Name   string `json:"name"`
				Avatar string `json:"avatar"`
			}
			h.db.Table("agents").Where("id = ?", p.ParticipantID).First(&a)
			participantDetails[i] = gin.H{
				"type": "agent",
				"id":   a.ID,
				"name": a.Name,
				"avatar": a.Avatar,
			}
		}
	}

	response.Success(c, gin.H{
		"id":           conv.ID,
		"type":         conv.Type,
		"name":         conv.Name,
		"org_id":       conv.OrgID,
		"participants": participantDetails,
		"created_at":   conv.CreatedAt,
	})
}

// List 获取会话列表
func (h *ConversationHandler) List(c *gin.Context) {
	claims, _ := c.Get("claims").(*jwt.Claims)

	convs, err := h.convRepo.GetUserConversations(c.Request.Context(), claims.UserID)
	if err != nil {
		response.InternalError(c, "获取会话列表失败")
		return
	}

	result := make([]gin.H, len(convs))
	for i, conv := range convs {
		result[i] = gin.H{
			"id":         conv.ID,
			"type":       conv.Type,
			"name":       conv.Name,
			"org_id":     conv.OrgID,
			"created_at": conv.CreatedAt,
			"updated_at": conv.UpdatedAt,
		}
	}

	response.Success(c, result)
}

// GetByID 获取会话详情
func (h *ConversationHandler) GetByID(c *gin.Context) {
	convID := c.Param("id")
	claims, _ := c.Get("claims").(*jwt.Claims)

	conv, err := h.convRepo.GetByID(c.Request.Context(), convID)
	if err != nil {
		response.NotFound(c, "会话不存在")
		return
	}

	// 验证用户是否是参与者
	isParticipant, err := h.convRepo.IsParticipant(c.Request.Context(), convID, "user", claims.UserID)
	if err != nil || !isParticipant {
		response.Forbidden(c, "无权访问该会话")
		return
	}

	// 获取参与者
	participants, _ := h.convRepo.GetParticipants(c.Request.Context(), convID)
	participantDetails := make([]gin.H, len(participants))

	for i, p := range participants {
		if p.ParticipantType == "user" {
			var u struct {
				ID     string `json:"id"`
				Name   string `json:"name"`
				Avatar string `json:"avatar"`
			}
			h.db.Table("users").Where("id = ?", p.ParticipantID).First(&u)
			participantDetails[i] = gin.H{
				"type": "user",
				"id":   u.ID,
				"name": u.Name,
				"avatar": u.Avatar,
			}
		} else {
			var a struct {
				ID     string `json:"id"`
				Name   string `json:"name"`
				Avatar string `json:"avatar"`
			}
			h.db.Table("agents").Where("id = ?", p.ParticipantID).First(&a)
			participantDetails[i] = gin.H{
				"type": "agent",
				"id":   a.ID,
				"name": a.Name,
				"avatar": a.Avatar,
			}
		}
	}

	response.Success(c, gin.H{
		"id":           conv.ID,
		"type":         conv.Type,
		"name":         conv.Name,
		"org_id":       conv.OrgID,
		"participants": participantDetails,
		"created_at":   conv.CreatedAt,
	})
}

// Update 更新会话信息
func (h *ConversationHandler) Update(c *gin.Context) {
	convID := c.Param("id")

	var req struct {
		Name string `json:"name"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	conv, err := h.convRepo.GetByID(c.Request.Context(), convID)
	if err != nil {
		response.NotFound(c, "会话不存在")
		return
	}

	if req.Name != "" {
		conv.Name = req.Name
	}

	if err := h.convRepo.Update(c.Request.Context(), conv); err != nil {
		response.InternalError(c, "更新失败")
		return
	}

	response.Success(c, gin.H{
		"id":   conv.ID,
		"name": conv.Name,
	})
}

// Delete 删除/退出会话
func (h *ConversationHandler) Delete(c *gin.Context) {
	convID := c.Param("id")
	claims, _ := c.Get("claims").(*jwt.Claims)

	// 验证用户是否是参与者
	isParticipant, err := h.convRepo.IsParticipant(c.Request.Context(), convID, "user", claims.UserID)
	if err != nil || !isParticipant {
		response.Forbidden(c, "无权操作")
		return
	}

	// 退出会话
	if err := h.convRepo.RemoveParticipant(c.Request.Context(), convID, "user", claims.UserID); err != nil {
		response.InternalError(c, "退出失败")
		return
	}

	response.Success(c, nil)
}

// AddParticipant 添加参与者
func (h *ConversationHandler) AddParticipant(c *gin.Context) {
	convID := c.Param("id")
	claims, _ := c.Get("claims").(*jwt.Claims)

	var req struct {
		Type string `json:"type" binding:"required,oneof=user agent"`
		ID   string `json:"id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	// 验证用户是否是参与者
	isParticipant, err := h.convRepo.IsParticipant(c.Request.Context(), convID, "user", claims.UserID)
	if err != nil || !isParticipant {
		response.Forbidden(c, "无权操作")
		return
	}

	// 获取会话信息
	conv, _ := h.convRepo.GetByID(c.Request.Context(), convID)

	// 验证被添加者是否在组织中
	if req.Type == "user" {
		isMember, _ := h.orgRepo.IsMember(c.Request.Context(), conv.OrgID, req.ID)
		if !isMember {
			response.BadRequest(c, 400002, "该用户不在组织中")
			return
		}
	} else {
		isInOrg, _ := h.agentRepo.IsInOrg(c.Request.Context(), req.ID, conv.OrgID)
		if !isInOrg {
			response.BadRequest(c, 400003, "该 Agent 不在组织中")
			return
		}
	}

	// 检查是否已经是参与者
	isAlreadyParticipant, _ := h.convRepo.IsParticipant(c.Request.Context(), convID, req.Type, req.ID)
	if isAlreadyParticipant {
		response.Error(c, 409, 409001, "已经是参与者")
		return
	}

	participant := &conversation.Participant{
		ConversationID:  convID,
		ParticipantType: req.Type,
		ParticipantID:   req.ID,
		JoinedAt:        time.Now(),
	}

	if err := h.convRepo.AddParticipant(c.Request.Context(), participant); err != nil {
		response.InternalError(c, "添加失败")
		return
	}

	response.Success(c, nil)
}

// RemoveParticipant 移除参与者
func (h *ConversationHandler) RemoveParticipant(c *gin.Context) {
	convID := c.Param("id")
	participantID := c.Param("pid")
	participantType := c.Query("type")

	if participantType == "" {
		participantType = "user"
	}

	claims, _ := c.Get("claims").(*jwt.Claims)

	// 验证用户是否是参与者
	isParticipant, err := h.convRepo.IsParticipant(c.Request.Context(), convID, "user", claims.UserID)
	if err != nil || !isParticipant {
		response.Forbidden(c, "无权操作")
		return
	}

	if err := h.convRepo.RemoveParticipant(c.Request.Context(), convID, participantType, participantID); err != nil {
		response.InternalError(c, "移除失败")
		return
	}

	response.Success(c, nil)
}