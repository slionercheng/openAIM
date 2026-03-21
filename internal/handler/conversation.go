package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/your-org/openim/internal/domain/agent"
	"github.com/your-org/openim/internal/domain/conversation"
	"github.com/your-org/openim/internal/domain/message"
	"github.com/your-org/openim/internal/domain/organization"
	"github.com/your-org/openim/internal/ws"
	"github.com/your-org/openim/pkg/idgen"
	"github.com/your-org/openim/pkg/jwt"
	"github.com/your-org/openim/pkg/logger"
	"github.com/your-org/openim/pkg/response"
	"gorm.io/gorm"
)

type ConversationHandler struct {
	db       *gorm.DB
	convRepo conversation.Repository
	orgRepo  organization.Repository
	agentRepo agent.Repository
	msgRepo  message.Repository
	hub      *ws.Hub
}

func NewConversationHandler(db *gorm.DB, hub *ws.Hub) *ConversationHandler {
	return &ConversationHandler{
		db:        db,
		convRepo:  conversation.NewRepository(db),
		orgRepo:   organization.NewRepository(db),
		agentRepo: agent.NewRepository(db),
		msgRepo:   message.NewRepository(db),
		hub:       hub,
	}
}

// createSystemMessage 创建系统消息并保存到数据库
func (h *ConversationHandler) createSystemMessage(ctx context.Context, convID, content string) (*message.Message, error) {
	logger.Infof("createSystemMessage: creating system message for convID=%s, content=%s", convID, content)
	msg := &message.Message{
		ID:             idgen.Generate(idgen.TypeMessage),
		ConversationID: convID,
		SenderType:     "system",
		SenderID:       "system",
		Content:        content,
		ContentType:    "system",
		CreatedAt:      time.Now(),
	}
	if err := h.msgRepo.Create(ctx, msg); err != nil {
		logger.Errorf("createSystemMessage: failed to save system message: %v", err)
		return nil, err
	}
	logger.Infof("createSystemMessage: successfully created system message id=%s", msg.ID)
	return msg, nil
}

type CreateConversationRequest struct {
	OrgID          string `json:"org_id"`
	Type           string `json:"type" binding:"required,oneof=direct group"`
	Name           string `json:"name"`
	IsPublic       bool   `json:"is_public"` // 群聊是否公开可搜索
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

	claims := c.MustGet("claims").(*jwt.Claims)

	// 私聊去重检查：如果已存在相同参与者的私聊，直接返回已有会话
	if req.Type == "direct" && len(req.ParticipantIDs) == 1 && req.ParticipantIDs[0].Type == "user" {
		existingConv, err := h.convRepo.FindDirectConversation(c.Request.Context(), claims.UserID, req.ParticipantIDs[0].ID)
		if err != nil {
			response.InternalError(c, "检查会话失败")
			return
		}
		if existingConv != nil {
			// 返回已有会话
			participants, _ := h.convRepo.GetParticipants(c.Request.Context(), existingConv.ID)
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
						"type":   "user",
						"id":     u.ID,
						"name":   u.Name,
						"avatar": u.Avatar,
						"role":   p.Role,
					}
				} else {
					var a struct {
						ID     string `json:"id"`
						Name   string `json:"name"`
						Avatar string `json:"avatar"`
					}
					h.db.Table("agents").Where("id = ?", p.ParticipantID).First(&a)
					participantDetails[i] = gin.H{
						"type":   "agent",
						"id":     a.ID,
						"name":   a.Name,
						"avatar": a.Avatar,
						"role":   p.Role,
					}
				}
			}
			response.Success(c, gin.H{
				"id":              existingConv.ID,
				"type":            existingConv.Type,
				"name":            existingConv.Name,
				"organization_id": existingConv.OrgID,
				"created_by":      existingConv.CreatedBy,
				"participants":    participantDetails,
				"created_at":      existingConv.CreatedAt,
				"updated_at":      existingConv.UpdatedAt,
				"existing":        true, // 标识这是已存在的会话
			})
			return
		}
	}

	// 私聊如果没有组织ID，跳过组织验证
	if req.OrgID != "" {
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
	}

	tx := h.db.Begin()

	conv := &conversation.Conversation{
		ID:        idgen.Generate(idgen.TypeConv),
		OrgID:     req.OrgID,
		Type:      req.Type,
		Name:      req.Name,
		IsPublic:  req.IsPublic,
		CreatedBy: claims.UserID,
	}

	if err := h.convRepo.Create(c.Request.Context(), conv); err != nil {
		tx.Rollback()
		response.InternalError(c, "创建会话失败")
		return
	}

	// 添加创建者作为参与者（群主）
	creatorParticipant := &conversation.Participant{
		ConversationID:  conv.ID,
		ParticipantType: "user",
		ParticipantID:   claims.UserID,
		Role:            conversation.RoleOwner, // 创建者是群主
		JoinedAt:        time.Now(),
	}
	if err := h.convRepo.AddParticipant(c.Request.Context(), creatorParticipant); err != nil {
		tx.Rollback()
		response.InternalError(c, "添加参与者失败")
		return
	}

	// 添加其他参与者
	participantMap := make(map[string]bool)
	participantMap["user_"+claims.UserID] = true // 创建者已添加，使用与循环相同的 key 格式

	for _, p := range req.ParticipantIDs {
		key := p.Type + "_" + p.ID
		if participantMap[key] {
			continue // 跳过已添加的参与者（包括创建者自己）
		}
		participantMap[key] = true

		participant := &conversation.Participant{
			ConversationID:  conv.ID,
			ParticipantType: p.Type,
			ParticipantID:   p.ID,
			Role:            conversation.RoleMember, // 其他参与者默认是成员
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
				"type":  "user",
				"id":    u.ID,
				"name":  u.Name,
				"avatar": u.Avatar,
				"role":  p.Role,
			}
		} else {
			var a struct {
				ID     string `json:"id"`
				Name   string `json:"name"`
				Avatar string `json:"avatar"`
			}
			h.db.Table("agents").Where("id = ?", p.ParticipantID).First(&a)
			participantDetails[i] = gin.H{
				"type":  "agent",
				"id":    a.ID,
				"name":  a.Name,
				"avatar": a.Avatar,
				"role":  p.Role,
			}
		}
	}

	// 通知其他参与者他们被加入了群聊
	if h.hub != nil && conv.Type == "group" {
		// 获取创建者名称
		var creatorName string
		h.db.Table("users").Where("id = ?", claims.UserID).Pluck("name", &creatorName)
		if creatorName == "" {
			creatorName = "用户"
		}

		// 通知每个被添加的参与者
		for _, p := range participants {
			if p.ParticipantType == "user" && p.ParticipantID != claims.UserID {
				h.hub.SendToUser(p.ParticipantID, gin.H{
					"type":              "group_joined",
					"conversation_id":   conv.ID,
					"conversation_name": conv.Name,
					"inviter_name":      creatorName,
				})
			}
		}
	}

	response.Success(c, gin.H{
		"id":              conv.ID,
		"type":            conv.Type,
		"name":            conv.Name,
		"is_public":       conv.IsPublic,
		"organization_id": conv.OrgID,
		"created_by":      conv.CreatedBy,
		"participants":    participantDetails,
		"created_at":      conv.CreatedAt,
		"updated_at":      conv.UpdatedAt,
	})
}

// List 获取会话列表
func (h *ConversationHandler) List(c *gin.Context) {
	claims := c.MustGet("claims").(*jwt.Claims)

	convs, err := h.convRepo.GetUserConversations(c.Request.Context(), claims.UserID)
	if err != nil {
		response.InternalError(c, "获取会话列表失败")
		return
	}

	result := make([]gin.H, len(convs))
	for i, conv := range convs {
		// 获取参与者
		participants, _ := h.convRepo.GetParticipants(c.Request.Context(), conv.ID)
		participantDetails := make([]gin.H, len(participants))

		for j, p := range participants {
			if p.ParticipantType == "user" {
				var u struct {
					ID     string `json:"id"`
					Name   string `json:"name"`
					Avatar string `json:"avatar"`
				}
				h.db.Table("users").Where("id = ?", p.ParticipantID).First(&u)
				participantDetails[j] = gin.H{
					"type":   "user",
					"id":     u.ID,
					"name":   u.Name,
					"avatar": u.Avatar,
					"role":   p.Role,
				}
			} else {
				var a struct {
					ID     string `json:"id"`
					Name   string `json:"name"`
					Avatar string `json:"avatar"`
				}
				h.db.Table("agents").Where("id = ?", p.ParticipantID).First(&a)
				participantDetails[j] = gin.H{
					"type":   "agent",
					"id":     a.ID,
					"name":   a.Name,
					"avatar": a.Avatar,
					"role":   p.Role,
				}
			}
		}

		result[i] = gin.H{
			"id":           conv.ID,
			"type":         conv.Type,
			"name":         conv.Name,
			"is_public":    conv.IsPublic,
			"org_id":       conv.OrgID,
			"created_at":   conv.CreatedAt,
			"updated_at":   conv.UpdatedAt,
			"participants": participantDetails,
		}
	}

	response.Success(c, result)
}

// GetByID 获取会话详情
func (h *ConversationHandler) GetByID(c *gin.Context) {
	convID := c.Param("id")
	claims := c.MustGet("claims").(*jwt.Claims)

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
				"type":  "user",
				"id":    u.ID,
				"name":  u.Name,
				"avatar": u.Avatar,
				"role":  p.Role,
			}
		} else {
			var a struct {
				ID     string `json:"id"`
				Name   string `json:"name"`
				Avatar string `json:"avatar"`
			}
			h.db.Table("agents").Where("id = ?", p.ParticipantID).First(&a)
			participantDetails[i] = gin.H{
				"type":  "agent",
				"id":    a.ID,
				"name":  a.Name,
				"avatar": a.Avatar,
				"role":  p.Role,
			}
		}
	}

	response.Success(c, gin.H{
		"id":           conv.ID,
		"type":         conv.Type,
		"name":         conv.Name,
		"is_public":    conv.IsPublic,
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
	claims := c.MustGet("claims").(*jwt.Claims)

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
	claims := c.MustGet("claims").(*jwt.Claims)

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
		Role:            conversation.RoleMember, // 添加的参与者默认是成员
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

	claims := c.MustGet("claims").(*jwt.Claims)

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

// SearchGroups 搜索公开群聊
func (h *ConversationHandler) SearchGroups(c *gin.Context) {
	query := c.Query("q")
	limit := 20
	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	convs, err := h.convRepo.SearchPublicGroups(c.Request.Context(), query, limit)
	if err != nil {
		response.InternalError(c, "搜索失败")
		return
	}

	result := make([]gin.H, len(convs))
	for i, conv := range convs {
		// 获取参与者数量
		participants, _ := h.convRepo.GetParticipants(c.Request.Context(), conv.ID)

		// 获取创建者信息
		var creatorName string
		h.db.Table("users").Where("id = ?", conv.CreatedBy).Pluck("name", &creatorName)

		result[i] = gin.H{
			"id":               conv.ID,
			"name":             conv.Name,
			"participant_count": len(participants),
			"created_by":       conv.CreatedBy,
			"creator_name":     creatorName,
			"created_at":       conv.CreatedAt,
		}
	}

	response.Success(c, result)
}

// CreateJoinRequest 申请加入群聊
func (h *ConversationHandler) CreateJoinRequest(c *gin.Context) {
	convID := c.Param("id")
	claims := c.MustGet("claims").(*jwt.Claims)

	var req struct {
		Message string `json:"message"`
	}
	c.ShouldBindJSON(&req)

	// 获取会话信息
	conv, err := h.convRepo.GetByID(c.Request.Context(), convID)
	if err != nil {
		response.NotFound(c, "会话不存在")
		return
	}

	// 只能申请加入群聊
	if conv.Type != "group" {
		response.BadRequest(c, 400001, "只能申请加入群聊")
		return
	}

	// 检查是否已经是参与者
	isParticipant, _ := h.convRepo.IsParticipant(c.Request.Context(), convID, "user", claims.UserID)
	if isParticipant {
		response.Error(c, 400, 400002, "已经是群成员")
		return
	}

	// 检查是否已有待处理的申请
	existingReq, _ := h.convRepo.GetUserJoinRequest(c.Request.Context(), convID, claims.UserID)
	if existingReq != nil && existingReq.Status == "pending" {
		response.Error(c, 400, 400003, "已有待处理的申请")
		return
	}

	// 创建申请
	joinReq := &conversation.JoinRequest{
		ID:             idgen.Generate(idgen.TypeConv),
		ConversationID: convID,
		UserID:         claims.UserID,
		Status:         conversation.JoinStatusPending,
		Message:        req.Message,
	}

	if err := h.convRepo.CreateJoinRequest(c.Request.Context(), joinReq); err != nil {
		response.InternalError(c, "创建申请失败")
		return
	}

	response.Success(c, gin.H{
		"id":              joinReq.ID,
		"conversation_id": joinReq.ConversationID,
		"status":          joinReq.Status,
	})
}

// GetJoinRequests 获取群聊加入申请列表
func (h *ConversationHandler) GetJoinRequests(c *gin.Context) {
	convID := c.Param("id")
	claims := c.MustGet("claims").(*jwt.Claims)

	// 验证用户是否是参与者
	isParticipant, err := h.convRepo.IsParticipant(c.Request.Context(), convID, "user", claims.UserID)
	if err != nil || !isParticipant {
		response.Forbidden(c, "无权查看")
		return
	}

	requests, err := h.convRepo.GetPendingJoinRequests(c.Request.Context(), convID)
	if err != nil {
		response.InternalError(c, "获取申请列表失败")
		return
	}

	result := make([]gin.H, len(requests))
	for i, req := range requests {
		var user struct {
			ID     string `json:"id"`
			Name   string `json:"name"`
			Email  string `json:"email"`
			Avatar string `json:"avatar"`
		}
		h.db.Table("users").Where("id = ?", req.UserID).First(&user)

		result[i] = gin.H{
			"id":         req.ID,
			"user":       user,
			"message":    req.Message,
			"status":     req.Status,
			"created_at": req.CreatedAt,
		}
	}

	response.Success(c, result)
}

// HandleJoinRequest 处理加入申请
func (h *ConversationHandler) HandleJoinRequest(c *gin.Context) {
	reqID := c.Param("request_id")
	action := c.Param("action") // accept 或 reject
	claims := c.MustGet("claims").(*jwt.Claims)

	// 获取申请
	req, err := h.convRepo.GetJoinRequest(c.Request.Context(), reqID)
	if err != nil {
		response.NotFound(c, "申请不存在")
		return
	}

	// 验证用户是否是群成员
	isParticipant, _ := h.convRepo.IsParticipant(c.Request.Context(), req.ConversationID, "user", claims.UserID)
	if !isParticipant {
		response.Forbidden(c, "无权处理申请")
		return
	}

	// 验证申请状态
	if req.Status != conversation.JoinStatusPending {
		response.BadRequest(c, 400001, "该申请已被处理")
		return
	}

	// 更新申请状态
	if action == "accept" {
		req.Status = conversation.JoinStatusAccepted
		// 添加用户为参与者
		participant := &conversation.Participant{
			ConversationID:  req.ConversationID,
			ParticipantType: "user",
			ParticipantID:   req.UserID,
			Role:            conversation.RoleMember, // 加入的成员默认是普通成员
			JoinedAt:        time.Now(),
		}
		if err := h.convRepo.AddParticipant(c.Request.Context(), participant); err != nil {
			response.InternalError(c, "添加成员失败")
			return
		}
	} else {
		req.Status = conversation.JoinStatusRejected
	}

	if err := h.convRepo.UpdateJoinRequest(c.Request.Context(), req); err != nil {
		response.InternalError(c, "更新申请状态失败")
		return
	}

	response.Success(c, gin.H{
		"id":     req.ID,
		"status": req.Status,
	})
}

// LeaveConversation 退出群聊
func (h *ConversationHandler) LeaveConversation(c *gin.Context) {
	convID := c.Param("id")
	claims := c.MustGet("claims").(*jwt.Claims)

	// 获取会话
	conv, err := h.convRepo.GetByID(c.Request.Context(), convID)
	if err != nil {
		response.NotFound(c, "会话不存在")
		return
	}

	// 只能退出群聊
	if conv.Type != "group" {
		response.BadRequest(c, 400001, "只能退出群聊")
		return
	}

	// 验证用户是否是参与者
	isParticipant, err := h.convRepo.IsParticipant(c.Request.Context(), convID, "user", claims.UserID)
	if err != nil || !isParticipant {
		response.Forbidden(c, "您不是该群成员")
		return
	}

	// 获取用户名称（用于系统消息）
	var userName string
	h.db.Table("users").Where("id = ?", claims.UserID).Pluck("name", &userName)
	if userName == "" {
		userName = "用户"
	}

	// 获取当前用户参与者信息（检查是否是群主）
	currentParticipant, _ := h.convRepo.GetParticipant(c.Request.Context(), convID, "user", claims.UserID)
	isOwner := currentParticipant != nil && currentParticipant.Role == conversation.RoleOwner

	// 获取所有参与者
	participants, _ := h.convRepo.GetParticipants(c.Request.Context(), convID)

	// 如果是群主离开，需要转让群主
	var newOwnerID string
	var newOwnerName string
	if isOwner && len(participants) > 1 {
		// 找到新群主：优先选择管理员，其次是加入时间最早的成员
		var newOwner *conversation.Participant
		for i := range participants {
			p := &participants[i]
			if p.ParticipantID == claims.UserID {
				continue // 跳过自己
			}
			if p.Role == conversation.RoleAdmin {
				newOwner = p
				break
			}
			if newOwner == nil || p.JoinedAt.Before(newOwner.JoinedAt) {
				newOwner = p
			}
		}
		if newOwner != nil {
			newOwnerID = newOwner.ParticipantID
			// 更新新群主角色
			newOwner.Role = conversation.RoleOwner
			h.convRepo.UpdateParticipant(c.Request.Context(), newOwner)
			// 获取新群主名称
			h.db.Table("users").Where("id = ?", newOwnerID).Pluck("name", &newOwnerName)
			if newOwnerName == "" {
				newOwnerName = "用户"
			}
		}
	}

	// 移除参与者
	if err := h.convRepo.RemoveParticipant(c.Request.Context(), convID, "user", claims.UserID); err != nil {
		response.InternalError(c, "退出失败")
		return
	}

	// 检查剩余成员数量
	remainingParticipants, _ := h.convRepo.GetParticipants(c.Request.Context(), convID)

	if len(remainingParticipants) == 0 {
		// 群聊没有成员了，自动解散
		logger.Infof("Group %s has no members left, auto-dissolving", convID)

		// 删除会话
		h.convRepo.Delete(c.Request.Context(), convID)

		// 删除相关消息
		h.db.Exec("DELETE FROM messages WHERE conversation_id = ?", convID)

		// 删除相关邀请
		h.db.Exec("DELETE FROM group_invitations WHERE conversation_id = ?", convID)

		// 删除加入请求
		h.db.Exec("DELETE FROM group_join_requests WHERE conversation_id = ?", convID)

		response.Success(c, gin.H{"dissolved": true})
		return
	}

	// 创建系统消息
	var systemContent string
	if isOwner && newOwnerID != "" {
		systemContent = fmt.Sprintf("%s 离开了群聊，%s 成为新群主", userName, newOwnerName)
	} else {
		systemContent = fmt.Sprintf("%s 离开了群聊", userName)
	}

	systemMsg, err := h.createSystemMessage(c.Request.Context(), convID, systemContent)
	if err != nil {
		logger.Warnf("Failed to create system message for member left: %v", err)
	}

	// 更新会话更新时间
	h.db.Exec("UPDATE conversations SET updated_at = ? WHERE id = ?", time.Now(), convID)

	// 广播成员离开事件给其他成员（包含系统消息）
	if h.hub != nil {
		// 发送系统消息给离开的用户（让他们在客户端看到系统消息）
		if systemMsg != nil {
			h.hub.SendToUser(claims.UserID, gin.H{
				"type":            "new_message",
				"id":              systemMsg.ID,
				"conversation_id": convID,
				"sender_type":     "system",
				"sender_id":       "system",
				"content":         systemMsg.Content,
				"content_type":    "system",
				"created_at":      systemMsg.CreatedAt,
			})
		}

		broadcastData := gin.H{
			"type":           "member_left",
			"conversation_id": convID,
			"sender_id":      claims.UserID,
			"sender_name":    userName,
			"user_id":        claims.UserID,
			"user_name":      userName,
			"created_at":     time.Now(),
		}
		// 添加系统消息到广播
		if systemMsg != nil {
			broadcastData["system_message"] = gin.H{
				"id":          systemMsg.ID,
				"content":     systemMsg.Content,
				"created_at":  systemMsg.CreatedAt,
			}
		}
		// 如果有新群主，添加到广播
		if newOwnerID != "" {
			broadcastData["new_owner_id"] = newOwnerID
			broadcastData["new_owner_name"] = newOwnerName
		}
		h.hub.BroadcastToConversation(convID, broadcastData, claims.UserID)
	}

	response.Success(c, gin.H{"dissolved": false})
}

// UpdateGroupSettings 更新群聊设置
func (h *ConversationHandler) UpdateGroupSettings(c *gin.Context) {
	convID := c.Param("id")
	claims := c.MustGet("claims").(*jwt.Claims)

	var req struct {
		Name     *string `json:"name"`
		IsPublic *bool   `json:"is_public"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	// 获取会话
	conv, err := h.convRepo.GetByID(c.Request.Context(), convID)
	if err != nil {
		response.NotFound(c, "会话不存在")
		return
	}

	// 检查是否是群主
	if conv.CreatedBy != claims.UserID {
		response.Forbidden(c, "只有群主可以修改群设置")
		return
	}

	// 更新设置
	if req.Name != nil {
		conv.Name = *req.Name
	}
	if req.IsPublic != nil {
		conv.IsPublic = *req.IsPublic
	}

	if err := h.convRepo.Update(c.Request.Context(), conv); err != nil {
		response.InternalError(c, "更新失败")
		return
	}

	response.Success(c, gin.H{
		"id":        conv.ID,
		"name":      conv.Name,
		"is_public": conv.IsPublic,
	})
}

// SetParticipantRole 设置成员角色
func (h *ConversationHandler) SetParticipantRole(c *gin.Context) {
	convID := c.Param("id")
	participantID := c.Param("pid")
	claims := c.MustGet("claims").(*jwt.Claims)

	var req struct {
		Role string `json:"role" binding:"required,oneof=owner admin member"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	// 获取会话
	conv, err := h.convRepo.GetByID(c.Request.Context(), convID)
	if err != nil {
		response.NotFound(c, "会话不存在")
		return
	}

	// 检查是否是群主
	if conv.CreatedBy != claims.UserID {
		response.Forbidden(c, "只有群主可以设置管理员")
		return
	}

	// 不能修改群主角色
	if participantID == conv.CreatedBy {
		response.BadRequest(c, 400002, "不能修改群主角色")
		return
	}

	// 获取参与者
	participant, err := h.convRepo.GetParticipant(c.Request.Context(), convID, "user", participantID)
	if participant == nil {
		response.NotFound(c, "成员不存在")
		return
	}

	// 更新角色
	participant.Role = req.Role
	if err := h.convRepo.UpdateParticipant(c.Request.Context(), participant); err != nil {
		response.InternalError(c, "更新失败")
		return
	}

	response.Success(c, gin.H{
		"id":   participantID,
		"role": participant.Role,
	})
}

// MuteParticipant 禁言成员
func (h *ConversationHandler) MuteParticipant(c *gin.Context) {
	convID := c.Param("id")
	participantID := c.Param("pid")
	claims := c.MustGet("claims").(*jwt.Claims)

	var req struct {
		Duration int `json:"duration"` // 禁言时长（分钟），0表示永久
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		req.Duration = 0 // 默认永久
	}

	// 检查是否是管理员或群主
	isAdmin, err := h.convRepo.IsOwnerOrAdmin(c.Request.Context(), convID, claims.UserID)
	if err != nil || !isAdmin {
		response.Forbidden(c, "只有管理员可以禁言成员")
		return
	}

	// 获取参与者
	participant, err := h.convRepo.GetParticipant(c.Request.Context(), convID, "user", participantID)
	if participant == nil {
		response.NotFound(c, "成员不存在")
		return
	}

	// 不能禁言群主
	conv, _ := h.convRepo.GetByID(c.Request.Context(), convID)
	if participantID == conv.CreatedBy {
		response.BadRequest(c, 400002, "不能禁言群主")
		return
	}

	// 设置禁言
	participant.IsMuted = true
	if req.Duration > 0 {
		mutedUntil := time.Now().Add(time.Duration(req.Duration) * time.Minute)
		participant.MutedUntil = &mutedUntil
	} else {
		participant.MutedUntil = nil
	}

	if err := h.convRepo.UpdateParticipant(c.Request.Context(), participant); err != nil {
		response.InternalError(c, "禁言失败")
		return
	}

	response.Success(c, gin.H{
		"id":          participantID,
		"is_muted":    participant.IsMuted,
		"muted_until": participant.MutedUntil,
	})
}

// UnmuteParticipant 解除禁言
func (h *ConversationHandler) UnmuteParticipant(c *gin.Context) {
	convID := c.Param("id")
	participantID := c.Param("pid")
	claims := c.MustGet("claims").(*jwt.Claims)

	// 检查是否是管理员或群主
	isAdmin, err := h.convRepo.IsOwnerOrAdmin(c.Request.Context(), convID, claims.UserID)
	if err != nil || !isAdmin {
		response.Forbidden(c, "只有管理员可以解除禁言")
		return
	}

	// 获取参与者
	participant, err := h.convRepo.GetParticipant(c.Request.Context(), convID, "user", participantID)
	if participant == nil {
		response.NotFound(c, "成员不存在")
		return
	}

	// 解除禁言
	participant.IsMuted = false
	participant.MutedUntil = nil

	if err := h.convRepo.UpdateParticipant(c.Request.Context(), participant); err != nil {
		response.InternalError(c, "解除禁言失败")
		return
	}

	response.Success(c, nil)
}

// InviteMember 邀请成员
func (h *ConversationHandler) InviteMember(c *gin.Context) {
	convID := c.Param("id")
	claims := c.MustGet("claims").(*jwt.Claims)

	var req struct {
		UserID string `json:"user_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		logger.Warnf("InviteMember: parameter error: %v", err)
		response.BadRequest(c, 400001, "参数错误")
		return
	}
	logger.Infof("InviteMember: convID=%s, inviter=%s, invitee=%s", convID, claims.UserID, req.UserID)

	// 获取会话
	conv, err := h.convRepo.GetByID(c.Request.Context(), convID)
	if err != nil {
		logger.Warnf("InviteMember: conversation not found: %s", convID)
		response.NotFound(c, "会话不存在")
		return
	}

	// 检查邀请人是否是群成员
	isParticipant, _ := h.convRepo.IsParticipant(c.Request.Context(), convID, "user", claims.UserID)
	if !isParticipant {
		logger.Warnf("InviteMember: inviter %s is not a participant of %s", claims.UserID, convID)
		response.Forbidden(c, "您不是该群成员")
		return
	}

	// 检查被邀请人是否已是成员
	isAlreadyMember, _ := h.convRepo.IsParticipant(c.Request.Context(), convID, "user", req.UserID)
	if isAlreadyMember {
		logger.Warnf("InviteMember: invitee %s is already a member of %s", req.UserID, convID)
		response.BadRequest(c, 400002, "该用户已是群成员")
		return
	}

	// 检查是否已有待处理的邀请
	existingInv, _ := h.convRepo.GetUserInvitation(c.Request.Context(), convID, req.UserID)
	if existingInv != nil && existingInv.Status == conversation.InvitationStatusPending {
		logger.Warnf("InviteMember: invitee %s already has pending invitation for %s", req.UserID, convID)
		response.BadRequest(c, 400003, "该用户已被邀请")
		return
	}
	// 如果有已拒绝的邀请，删除它以便重新邀请
	if existingInv != nil && existingInv.Status == conversation.InvitationStatusRejected {
		h.db.Delete(existingInv)
	}

	// 判断是否是群主或管理员邀请
	isAdmin, _ := h.convRepo.IsOwnerOrAdmin(c.Request.Context(), convID, claims.UserID)
	logger.Infof("InviteMember: IsOwnerOrAdmin result: %v, conv.CreatedBy=%s, claims.UserID=%s", isAdmin, conv.CreatedBy, claims.UserID)

	// 如果是群创建者，也视为管理员（兼容旧数据，创建者角色可能还未设置为owner）
	if conv.CreatedBy == claims.UserID {
		isAdmin = true
		logger.Infof("InviteMember: User is creator, setting isAdmin=true")
	}

	// 获取群聊名称（用于通知）
	convName := conv.Name
	if convName == "" {
		convName = "群聊"
	}

	// 获取邀请人名称
	var inviterName string
	h.db.Table("users").Where("id = ?", claims.UserID).Pluck("name", &inviterName)
	if inviterName == "" {
		inviterName = "用户"
	}

	if isAdmin {
		// 管理员邀请直接加入
		participant := &conversation.Participant{
			ConversationID:  convID,
			ParticipantType: "user",
			ParticipantID:   req.UserID,
			Role:            conversation.RoleMember,
			JoinedAt:        time.Now(),
		}
		if err := h.convRepo.AddParticipant(c.Request.Context(), participant); err != nil {
			response.InternalError(c, "添加成员失败")
			return
		}

		// 获取新成员信息
		var newMember struct {
			ID     string `json:"id"`
			Name   string `json:"name"`
			Avatar string `json:"avatar"`
		}
		h.db.Table("users").Where("id = ?", req.UserID).First(&newMember)

		// 创建系统消息：xxx 加入了群聊
		systemContent := fmt.Sprintf("%s 加入了群聊", newMember.Name)
		systemMsg, err := h.createSystemMessage(c.Request.Context(), convID, systemContent)
		if err != nil {
			logger.Warnf("Failed to create system message for member joined: %v", err)
		}

		// 通知被邀请人
		if h.hub != nil {
			// 发送系统消息给被邀请人
			if systemMsg != nil {
				h.hub.SendToUser(req.UserID, gin.H{
					"type":            "new_message",
					"id":              systemMsg.ID,
					"conversation_id": convID,
					"sender_type":     "system",
					"sender_id":       "system",
					"content":         systemMsg.Content,
					"content_type":    "system",
					"created_at":      systemMsg.CreatedAt,
				})
			}

			// 通知被邀请人已加入群聊
			h.hub.SendToUser(req.UserID, gin.H{
				"type":              "group_joined",
				"conversation_id":   convID,
				"conversation_name": convName,
				"inviter_name":      inviterName,
			})

			// 广播新成员加入消息给群聊中其他成员（包含系统消息）
			broadcastData := gin.H{
				"type":              "member_joined",
				"conversation_id":   convID,
				"conversation_name": convName,
				"user_id":           req.UserID,
				"user_name":         newMember.Name,
				"user_avatar":       newMember.Avatar,
				"joined_at":         time.Now(),
			}
			// 添加系统消息到广播
			if systemMsg != nil {
				broadcastData["system_message"] = gin.H{
					"id":          systemMsg.ID,
					"content":     systemMsg.Content,
					"created_at":  systemMsg.CreatedAt,
				}
			}
			h.hub.BroadcastToConversation(convID, broadcastData, req.UserID) // 排除新成员自己
		}

		response.Success(c, gin.H{"status": "joined"})
	} else {
		// 普通成员邀请需要审批
		invitation := &conversation.Invitation{
			ID:             idgen.Generate(idgen.TypeConv),
			ConversationID: convID,
			InviterID:      claims.UserID,
			InviteeID:      req.UserID,
			Status:         conversation.InvitationStatusPending,
		}
		if err := h.convRepo.CreateInvitation(c.Request.Context(), invitation); err != nil {
			response.InternalError(c, "创建邀请失败")
			return
		}

		// 获取邀请者和被邀请者信息
		var inviterInfo struct {
			ID   string `json:"id"`
			Name string `json:"name"`
		}
		h.db.Table("users").Where("id = ?", claims.UserID).First(&inviterInfo)
		if inviterInfo.Name == "" {
			inviterInfo.Name = "用户"
		}

		var inviteeInfo struct {
			ID   string `json:"id"`
			Name string `json:"name"`
		}
		h.db.Table("users").Where("id = ?", req.UserID).First(&inviteeInfo)
		if inviteeInfo.Name == "" {
			inviteeInfo.Name = "用户"
		}

		// 创建邀请请求消息（显示在群聊中，仅管理员可见）
		metadataJSON, _ := json.Marshal(map[string]string{
			"invitation_id": invitation.ID,
			"inviter_id":    claims.UserID,
			"inviter_name":  inviterInfo.Name,
			"invitee_id":    req.UserID,
			"invitee_name":  inviteeInfo.Name,
			"status":        "pending",
		})
		inviteRequestMsg := &message.Message{
			ID:             idgen.Generate(idgen.TypeMessage),
			ConversationID: convID,
			SenderType:     "system",
			SenderID:       "system",
			Content:        fmt.Sprintf("%s 想要邀请 %s 加入群聊", inviterInfo.Name, inviteeInfo.Name),
			ContentType:    "invite_request",
			Metadata:       string(metadataJSON),
			CreatedAt:      time.Now(),
		}
		if err := h.msgRepo.Create(c.Request.Context(), inviteRequestMsg); err != nil {
			logger.Warnf("Failed to create invite request message: %v", err)
		}

		// 获取所有管理员
		admins, _ := h.convRepo.GetAdmins(c.Request.Context(), convID)

		if h.hub != nil {
			// 向群聊发送邀请请求消息（所有成员都能看到，但只有管理员能操作）
			msgData := gin.H{
				"type":            "new_message",
				"id":              inviteRequestMsg.ID,
				"conversation_id": convID,
				"sender_type":     "system",
				"sender_id":       "system",
				"content":         inviteRequestMsg.Content,
				"content_type":    "invite_request",
				"created_at":      inviteRequestMsg.CreatedAt,
				"metadata": gin.H{
					"invitation_id": invitation.ID,
					"inviter_id":    claims.UserID,
					"inviter_name":  inviterInfo.Name,
					"invitee_id":    req.UserID,
					"invitee_name":  inviteeInfo.Name,
					"status":        "pending",
				},
			}
			h.hub.BroadcastToConversation(convID, msgData, "")

			// 单独通知管理员有新的邀请请求待处理
			for _, admin := range admins {
				h.hub.SendToUser(admin.ParticipantID, gin.H{
					"type":              "invite_request_notification",
					"conversation_id":   convID,
					"conversation_name": convName,
					"invitation_id":     invitation.ID,
					"inviter_name":      inviterInfo.Name,
					"invitee_name":      inviteeInfo.Name,
				})
			}
		}

		response.Success(c, gin.H{
			"id":     invitation.ID,
			"status": "pending_approval",
		})
	}
}

// GetPendingInvitations 获取待审批的邀请
func (h *ConversationHandler) GetPendingInvitations(c *gin.Context) {
	convID := c.Param("id")
	claims := c.MustGet("claims").(*jwt.Claims)

	// 检查是否是管理员或群主
	isAdmin, err := h.convRepo.IsOwnerOrAdmin(c.Request.Context(), convID, claims.UserID)
	if err != nil || !isAdmin {
		response.Forbidden(c, "只有管理员可以查看邀请")
		return
	}

	invitations, err := h.convRepo.GetPendingInvitations(c.Request.Context(), convID)
	if err != nil {
		response.InternalError(c, "获取邀请列表失败")
		return
	}

	result := make([]gin.H, len(invitations))
	for i, inv := range invitations {
		var inviter struct {
			ID    string `json:"id"`
			Name  string `json:"name"`
			Email string `json:"email"`
		}
		h.db.Table("users").Where("id = ?", inv.InviterID).First(&inviter)

		var invitee struct {
			ID    string `json:"id"`
			Name  string `json:"name"`
			Email string `json:"email"`
		}
		h.db.Table("users").Where("id = ?", inv.InviteeID).First(&invitee)

		result[i] = gin.H{
			"id":         inv.ID,
			"inviter":    inviter,
			"invitee":    invitee,
			"status":     inv.Status,
			"created_at": inv.CreatedAt,
		}
	}

	response.Success(c, result)
}

// HandleInvitation 处理邀请审批（管理员审批普通成员的邀请请求）
func (h *ConversationHandler) HandleInvitation(c *gin.Context) {
	invID := c.Param("invitation_id")
	action := c.Param("action") // approve 或 reject
	claims := c.MustGet("claims").(*jwt.Claims)

	// 获取邀请
	inv, err := h.convRepo.GetInvitation(c.Request.Context(), invID)
	if err != nil {
		response.NotFound(c, "邀请不存在")
		return
	}

	// 检查邀请状态
	if inv.Status != conversation.InvitationStatusPending {
		response.BadRequest(c, 400001, "该邀请已被处理")
		return
	}

	// 检查是否是管理员或群主
	isAdmin, _ := h.convRepo.IsOwnerOrAdmin(c.Request.Context(), inv.ConversationID, claims.UserID)
	if !isAdmin {
		response.Forbidden(c, "只有管理员可以审批邀请")
		return
	}

	// 获取审批管理员信息
	var adminName string
	h.db.Table("users").Where("id = ?", claims.UserID).Pluck("name", &adminName)
	if adminName == "" {
		adminName = "管理员"
	}

	// 获取被邀请人信息
	var inviteeName string
	h.db.Table("users").Where("id = ?", inv.InviteeID).Pluck("name", &inviteeName)
	if inviteeName == "" {
		inviteeName = "用户"
	}

	// 获取会话名称
	conv, _ := h.convRepo.GetByID(c.Request.Context(), inv.ConversationID)
	convName := conv.Name
	if convName == "" {
		convName = "群聊"
	}

	// 更新邀请状态
	if action == "approve" {
		inv.Status = conversation.InvitationStatusApproved
		// 添加成员
		participant := &conversation.Participant{
			ConversationID:  inv.ConversationID,
			ParticipantType: "user",
			ParticipantID:   inv.InviteeID,
			Role:            conversation.RoleMember,
			JoinedAt:        time.Now(),
		}
		if err := h.convRepo.AddParticipant(c.Request.Context(), participant); err != nil {
			response.InternalError(c, "添加成员失败")
			return
		}

		// 创建系统消息：xxx 加入了群聊
		systemContent := fmt.Sprintf("%s 加入了群聊", inviteeName)
		systemMsg, err := h.createSystemMessage(c.Request.Context(), inv.ConversationID, systemContent)
		if err != nil {
			logger.Warnf("Failed to create system message for member joined: %v", err)
		}

		if h.hub != nil {
			// 发送系统消息给新成员
			if systemMsg != nil {
				h.hub.SendToUser(inv.InviteeID, gin.H{
					"type":            "new_message",
					"id":              systemMsg.ID,
					"conversation_id": inv.ConversationID,
					"sender_type":     "system",
					"sender_id":       "system",
					"content":         systemMsg.Content,
					"content_type":    "system",
					"created_at":      systemMsg.CreatedAt,
				})
			}

			// 通知被邀请人已加入群聊
			h.hub.SendToUser(inv.InviteeID, gin.H{
				"type":              "group_joined",
				"conversation_id":   inv.ConversationID,
				"conversation_name": convName,
				"inviter_name":      adminName,
			})

			// 广播新成员加入消息给群聊中其他成员
			broadcastData := gin.H{
				"type":              "member_joined",
				"conversation_id":   inv.ConversationID,
				"conversation_name": convName,
				"user_id":           inv.InviteeID,
				"user_name":         inviteeName,
				"joined_at":         time.Now(),
			}
			if systemMsg != nil {
				broadcastData["system_message"] = gin.H{
					"id":         systemMsg.ID,
					"content":    systemMsg.Content,
					"created_at": systemMsg.CreatedAt,
				}
			}
			h.hub.BroadcastToConversation(inv.ConversationID, broadcastData, inv.InviteeID)
		}
	} else {
		inv.Status = conversation.InvitationStatusRejected

		// 通知被邀请人邀请被拒绝
		if h.hub != nil {
			h.hub.SendToUser(inv.InviteeID, gin.H{
				"type":              "group_invitation_rejected",
				"invitation_id":     inv.ID,
				"conversation_id":   inv.ConversationID,
				"conversation_name": convName,
			})
		}
	}

	if err := h.convRepo.UpdateInvitation(c.Request.Context(), inv); err != nil {
		response.InternalError(c, "更新邀请状态失败")
		return
	}

	// 更新邀请请求消息的状态（通过广播让所有客户端更新）
	if h.hub != nil {
		h.hub.BroadcastToConversation(inv.ConversationID, gin.H{
			"type":            "invite_request_updated",
			"conversation_id": inv.ConversationID,
			"invitation_id":   inv.ID,
			"status":          inv.Status,
			"approved_by":     adminName,
		}, "")
	}

	response.Success(c, gin.H{
		"id":     inv.ID,
		"status": inv.Status,
	})
}

// GetUserInvitations 获取用户收到的群邀请列表
func (h *ConversationHandler) GetUserInvitations(c *gin.Context) {
	claims := c.MustGet("claims").(*jwt.Claims)

	invitations, err := h.convRepo.GetUserPendingInvitations(c.Request.Context(), claims.UserID)
	if err != nil {
		response.InternalError(c, "获取邀请列表失败")
		return
	}

	result := make([]gin.H, len(invitations))
	for i, inv := range invitations {
		// 获取群聊信息
		conv, _ := h.convRepo.GetByID(c.Request.Context(), inv.ConversationID)

		// 获取邀请人信息
		var inviter struct {
			ID    string `json:"id"`
			Name  string `json:"name"`
			Email string `json:"email"`
		}
		h.db.Table("users").Where("id = ?", inv.InviterID).First(&inviter)

		result[i] = gin.H{
			"id":               inv.ID,
			"conversation_id":  inv.ConversationID,
			"conversation_name": conv.Name,
			"inviter":          inviter,
			"status":           inv.Status,
			"created_at":       inv.CreatedAt,
		}
	}

	response.Success(c, result)
}

// HandleUserInvitation 用户处理收到的群邀请（接受/拒绝）
func (h *ConversationHandler) HandleUserInvitation(c *gin.Context) {
	invID := c.Param("invitation_id")
	action := c.Param("action") // accept 或 reject
	claims := c.MustGet("claims").(*jwt.Claims)

	// 获取邀请
	inv, err := h.convRepo.GetInvitation(c.Request.Context(), invID)
	if err != nil {
		response.NotFound(c, "邀请不存在")
		return
	}

	// 验证是否是被邀请人
	if inv.InviteeID != claims.UserID {
		response.Forbidden(c, "无权处理此邀请")
		return
	}

	// 验证邀请状态
	if inv.Status != conversation.InvitationStatusPending {
		response.BadRequest(c, 400001, "该邀请已被处理")
		return
	}

	// 更新邀请状态
	if action == "accept" {
		inv.Status = conversation.InvitationStatusApproved
		// 添加成员
		participant := &conversation.Participant{
			ConversationID:  inv.ConversationID,
			ParticipantType: "user",
			ParticipantID:   claims.UserID,
			Role:            conversation.RoleMember,
			JoinedAt:        time.Now(),
		}
		if err := h.convRepo.AddParticipant(c.Request.Context(), participant); err != nil {
			response.InternalError(c, "加入群聊失败")
			return
		}

		// 通知群聊中其他成员有新成员加入
		if h.hub != nil {
			// 获取新成员信息
			var newMember struct {
				ID     string `json:"id"`
				Name   string `json:"name"`
				Avatar string `json:"avatar"`
			}
			h.db.Table("users").Where("id = ?", claims.UserID).First(&newMember)

			// 获取群聊名称
			var convName string
			h.db.Table("conversations").Where("id = ?", inv.ConversationID).Pluck("name", &convName)

			// 广播新成员加入消息给所有参与者
			h.hub.BroadcastToConversation(inv.ConversationID, gin.H{
				"type":              "member_joined",
				"conversation_id":   inv.ConversationID,
				"conversation_name": convName,
				"user_id":           claims.UserID,
				"user_name":         newMember.Name,
				"user_avatar":       newMember.Avatar,
				"joined_at":         time.Now(),
			}, claims.UserID) // 排除自己
		}
	} else {
		inv.Status = conversation.InvitationStatusRejected
	}

	if err := h.convRepo.UpdateInvitation(c.Request.Context(), inv); err != nil {
		response.InternalError(c, "更新邀请状态失败")
		return
	}

	response.Success(c, gin.H{
		"id":     inv.ID,
		"status": inv.Status,
	})
}

// DissolveGroup 解散群聊
func (h *ConversationHandler) DissolveGroup(c *gin.Context) {
	convID := c.Param("id")
	claims := c.MustGet("claims").(*jwt.Claims)

	// 获取会话
	conv, err := h.convRepo.GetByID(c.Request.Context(), convID)
	if err != nil {
		response.NotFound(c, "会话不存在")
		return
	}

	// 只能解散群聊
	if conv.Type != "group" {
		response.BadRequest(c, 400001, "只能解散群聊")
		return
	}

	// 检查是否是群主或管理员
	isAdmin, err := h.convRepo.IsOwnerOrAdmin(c.Request.Context(), convID, claims.UserID)
	if err != nil || !isAdmin {
		response.Forbidden(c, "只有群主或管理员可以解散群聊")
		return
	}

	// 获取群聊名称
	convName := conv.Name
	if convName == "" {
		convName = "群聊"
	}

	// 获取所有参与者（用于广播）
	participants, _ := h.convRepo.GetParticipants(c.Request.Context(), convID)

	// 广播解散消息给所有成员
	if h.hub != nil {
		for _, p := range participants {
			if p.ParticipantType == "user" {
				h.hub.SendToUser(p.ParticipantID, gin.H{
					"type":              "group_dissolved",
					"conversation_id":   convID,
					"conversation_name": convName,
					"message":           "当前群聊已解散",
					"created_at":        time.Now(),
				})
			}
		}
	}

	// 删除群聊相关数据
	// 1. 删除参与者
	h.db.Where("conversation_id = ?", convID).Delete(&conversation.Participant{})

	// 2. 删除消息
	h.db.Where("conversation_id = ?", convID).Delete(&message.Message{})

	// 3. 删除邀请
	h.db.Where("conversation_id = ?", convID).Delete(&conversation.Invitation{})

	// 4. 删除加入请求
	h.db.Where("conversation_id = ?", convID).Delete(&conversation.JoinRequest{})

	// 5. 删除会话
	h.db.Delete(conv)

	response.Success(c, gin.H{
		"id":      convID,
		"message": "群聊已解散",
	})
}