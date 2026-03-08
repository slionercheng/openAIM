package handler

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/your-org/openim/internal/domain/agent"
	"github.com/your-org/openim/internal/domain/organization"
	"github.com/your-org/openim/pkg/idgen"
	"github.com/your-org/openim/pkg/jwt"
	"github.com/your-org/openim/pkg/response"
	"gorm.io/gorm"
)

type AgentHandler struct {
	db        *gorm.DB
	agentRepo agent.Repository
	orgRepo   organization.Repository
	jwtConfig jwt.JWTConfig
}

func NewAgentHandler(db *gorm.DB, jwtConfig jwt.JWTConfig) *AgentHandler {
	return &AgentHandler{
		db:        db,
		agentRepo: agent.NewRepository(db),
		orgRepo:   organization.NewRepository(db),
		jwtConfig: jwtConfig,
	}
}

type CreateAgentRequest struct {
	Name        string   `json:"name" binding:"required,min=2,max=100"`
	Description string   `json:"description"`
	Avatar      string   `json:"avatar"`
	Skills      []string `json:"skills"`
	Metadata    map[string]interface{} `json:"metadata"`
}

// generateAccessToken 生成 Agent 访问令牌
func generateAccessToken() (string, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return "agt_secret_" + hex.EncodeToString(bytes), nil
}

// Create 创建 Agent
func (h *AgentHandler) Create(c *gin.Context) {
	var req CreateAgentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误: "+err.Error())
		return
	}

	claims := c.MustGet("claims").(*jwt.Claims)

	// 生成访问令牌
	accessToken, err := generateAccessToken()
	if err != nil {
		response.InternalError(c, "生成访问令牌失败")
		return
	}

	// 序列化 skills
	skillsJSON := "[]"
	if len(req.Skills) > 0 {
		skillsJSON = "["
		for i, s := range req.Skills {
			if i > 0 {
				skillsJSON += ","
			}
			skillsJSON += `"` + s + `"`
		}
		skillsJSON += "]"
	}

	ag := &agent.Agent{
		ID:          idgen.Generate(idgen.TypeAgent),
		Name:        req.Name,
		Description: req.Description,
		Avatar:      req.Avatar,
		Skills:      skillsJSON,
		OwnerID:     claims.UserID,
		AccessToken: accessToken,
		Status:      "inactive",
	}

	if err := h.agentRepo.Create(c.Request.Context(), ag); err != nil {
		response.InternalError(c, "创建 Agent 失败")
		return
	}

	response.Success(c, gin.H{
		"id":           ag.ID,
		"name":         ag.Name,
		"description":  ag.Description,
		"avatar":       ag.Avatar,
		"skills":       req.Skills,
		"owner_id":     ag.OwnerID,
		"status":       ag.Status,
		"access_token": ag.AccessToken, // 仅在创建时返回
		"created_at":   ag.CreatedAt,
	})
}

// GetByID 获取 Agent 详情
func (h *AgentHandler) GetByID(c *gin.Context) {
	agentID := c.Param("id")

	ag, err := h.agentRepo.GetByID(c.Request.Context(), agentID)
	if err != nil {
		response.NotFound(c, "Agent 不存在")
		return
	}

	// TODO: 验证权限

	response.Success(c, gin.H{
		"id":          ag.ID,
		"name":        ag.Name,
		"description": ag.Description,
		"avatar":      ag.Avatar,
		"skills":      ag.Skills,
		"owner_id":    ag.OwnerID,
		"status":      ag.Status,
		"created_at":  ag.CreatedAt,
	})
}

// Update 更新 Agent 信息
func (h *AgentHandler) Update(c *gin.Context) {
	agentID := c.Param("id")
	claims := c.MustGet("claims").(*jwt.Claims)

	ag, err := h.agentRepo.GetByID(c.Request.Context(), agentID)
	if err != nil {
		response.NotFound(c, "Agent 不存在")
		return
	}

	// 验证所有权
	if ag.OwnerID != claims.UserID {
		response.Forbidden(c, "无权修改该 Agent")
		return
	}

	var req struct {
		Name        string   `json:"name"`
		Description string   `json:"description"`
		Avatar      string   `json:"avatar"`
		Skills      []string `json:"skills"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	if req.Name != "" {
		ag.Name = req.Name
	}
	if req.Description != "" {
		ag.Description = req.Description
	}
	if req.Avatar != "" {
		ag.Avatar = req.Avatar
	}

	if err := h.agentRepo.Update(c.Request.Context(), ag); err != nil {
		response.InternalError(c, "更新失败")
		return
	}

	response.Success(c, gin.H{
		"id":          ag.ID,
		"name":        ag.Name,
		"description": ag.Description,
		"avatar":      ag.Avatar,
	})
}

// Delete 删除 Agent
func (h *AgentHandler) Delete(c *gin.Context) {
	agentID := c.Param("id")
	claims := c.MustGet("claims").(*jwt.Claims)

	ag, err := h.agentRepo.GetByID(c.Request.Context(), agentID)
	if err != nil {
		response.NotFound(c, "Agent 不存在")
		return
	}

	// 验证所有权
	if ag.OwnerID != claims.UserID {
		response.Forbidden(c, "无权删除该 Agent")
		return
	}

	if err := h.agentRepo.Delete(c.Request.Context(), agentID); err != nil {
		response.InternalError(c, "删除失败")
		return
	}

	response.Success(c, nil)
}

// CreateJoinRequest 申请加入组织
func (h *AgentHandler) CreateJoinRequest(c *gin.Context) {
	agentID := c.Param("id")

	var req struct {
		OrgID string `json:"org_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	// 验证 Agent 存在
	ag, err := h.agentRepo.GetByID(c.Request.Context(), agentID)
	if err != nil {
		response.NotFound(c, "Agent 不存在")
		return
	}

	// 验证 Agent 的 Owner 是否在组织中
	isMember, err := h.orgRepo.IsMember(c.Request.Context(), req.OrgID, ag.OwnerID)
	if err != nil || !isMember {
		response.BadRequest(c, 400002, "Agent 的所有者不在该组织中")
		return
	}

	// 检查是否已经申请或加入
	existingMembership, _ := h.agentRepo.GetOrgMembership(c.Request.Context(), agentID, req.OrgID)
	if existingMembership != nil {
		if existingMembership.Status == "approved" {
			response.Error(c, http.StatusConflict, 409002, "Agent 已在该组织中")
		} else {
			response.Error(c, http.StatusConflict, 409003, "已有待审批的申请")
		}
		return
	}

	joinRequest := &agent.JoinRequest{
		ID:      idgen.Generate(idgen.TypeJoinReq),
		AgentID: agentID,
		OrgID:   req.OrgID,
		Status:  "pending",
	}

	if err := h.agentRepo.CreateJoinRequest(c.Request.Context(), joinRequest); err != nil {
		response.InternalError(c, "创建申请失败")
		return
	}

	// 获取组织信息
	org, _ := h.orgRepo.GetByID(c.Request.Context(), req.OrgID)

	response.Success(c, gin.H{
		"request_id":  joinRequest.ID,
		"agent_id":    joinRequest.AgentID,
		"agent_name":  ag.Name,
		"org_id":      joinRequest.OrgID,
		"org_name":    org.Name,
		"status":      joinRequest.Status,
		"created_at":  joinRequest.CreatedAt,
	})
}

// GetJoinRequests 获取加入申请列表
func (h *AgentHandler) GetJoinRequests(c *gin.Context) {
	agentID := c.Param("id")

	requests, err := h.agentRepo.GetJoinRequestsByAgent(c.Request.Context(), agentID)
	if err != nil {
		response.InternalError(c, "获取申请列表失败")
		return
	}

	result := make([]gin.H, len(requests))
	for i, r := range requests {
		org, _ := h.orgRepo.GetByID(c.Request.Context(), r.OrgID)
		result[i] = gin.H{
			"request_id": r.ID,
			"org_id":     r.OrgID,
			"org_name":   org.Name,
			"status":     r.Status,
			"created_at": r.CreatedAt,
		}
	}

	response.Success(c, result)
}

// RegenerateToken 重新生成访问令牌
func (h *AgentHandler) RegenerateToken(c *gin.Context) {
	agentID := c.Param("id")
	claims := c.MustGet("claims").(*jwt.Claims)

	ag, err := h.agentRepo.GetByID(c.Request.Context(), agentID)
	if err != nil {
		response.NotFound(c, "Agent 不存在")
		return
	}

	// 验证所有权
	if ag.OwnerID != claims.UserID {
		response.Forbidden(c, "无权操作")
		return
	}

	newToken, err := generateAccessToken()
	if err != nil {
		response.InternalError(c, "生成令牌失败")
		return
	}

	ag.AccessToken = newToken
	if err := h.agentRepo.Update(c.Request.Context(), ag); err != nil {
		response.InternalError(c, "更新失败")
		return
	}

	response.Success(c, gin.H{
		"access_token": newToken,
	})
}