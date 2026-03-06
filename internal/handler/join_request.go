package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/your-org/openim/internal/domain/agent"
	"github.com/your-org/openim/internal/domain/organization"
	"github.com/your-org/openim/pkg/jwt"
	"github.com/your-org/openim/pkg/response"
	"gorm.io/gorm"
)

type JoinRequestHandler struct {
	db         *gorm.DB
	agentRepo  agent.Repository
	orgRepo    organization.Repository
}

func NewJoinRequestHandler(db *gorm.DB) *JoinRequestHandler {
	return &JoinRequestHandler{
		db:        db,
		agentRepo: agent.NewRepository(db),
		orgRepo:   organization.NewRepository(db),
	}
}

// List 获取待审批的申请列表
func (h *JoinRequestHandler) List(c *gin.Context) {
	claims, _ := c.Get("claims").(*jwt.Claims)
	orgID := c.Query("org_id")

	var requests []agent.JoinRequest

	if orgID != "" {
		// 验证是否为管理员
		role, err := h.orgRepo.GetMemberRole(c.Request.Context(), orgID, claims.UserID)
		if err != nil || (role != "owner" && role != "admin") {
			response.Forbidden(c, "无权查看")
			return
		}

		requests, _ = h.agentRepo.GetPendingJoinRequestsByOrg(c.Request.Context(), orgID)
	} else {
		// 获取用户所有组织的待审批申请
		orgs, _ := h.orgRepo.GetUserOrganizations(c.Request.Context(), claims.UserID)
		for _, org := range orgs {
			role, _ := h.orgRepo.GetMemberRole(c.Request.Context(), org.ID, claims.UserID)
			if role == "owner" || role == "admin" {
				orgRequests, _ := h.agentRepo.GetPendingJoinRequestsByOrg(c.Request.Context(), org.ID)
				requests = append(requests, orgRequests...)
			}
		}
	}

	// 补充信息
	result := make([]gin.H, len(requests))
	for i, r := range requests {
		ag, _ := h.agentRepo.GetByID(c.Request.Context(), r.AgentID)
		org, _ := h.orgRepo.GetByID(c.Request.Context(), r.OrgID)

		result[i] = gin.H{
			"request_id": r.ID,
			"status":     r.Status,
			"created_at": r.CreatedAt,
			"agent": gin.H{
				"id":          ag.ID,
				"name":        ag.Name,
				"description": ag.Description,
			},
			"org": gin.H{
				"id":   org.ID,
				"name": org.Name,
			},
		}
	}

	response.Success(c, result)
}

// Approve 批准申请
func (h *JoinRequestHandler) Approve(c *gin.Context) {
	requestID := c.Param("id")
	claims, _ := c.Get("claims").(*jwt.Claims)

	request, err := h.agentRepo.GetJoinRequestByID(c.Request.Context(), requestID)
	if err != nil {
		response.NotFound(c, "申请不存在")
		return
	}

	if request.Status != "pending" {
		response.BadRequest(c, 400001, "该申请已处理")
		return
	}

	// 验证是否为组织管理员
	role, err := h.orgRepo.GetMemberRole(c.Request.Context(), request.OrgID, claims.UserID)
	if err != nil || (role != "owner" && role != "admin") {
		response.Forbidden(c, "无权审批")
		return
	}

	tx := h.db.Begin()

	// 更新申请状态
	if err := h.agentRepo.UpdateJoinRequestStatus(c.Request.Context(), requestID, "approved"); err != nil {
		tx.Rollback()
		response.InternalError(c, "审批失败")
		return
	}

	// Agent 加入组织
	membership := &agent.AgentOrgMembership{
		AgentID:    request.AgentID,
		OrgID:      request.OrgID,
		Status:     "approved",
		ApprovedBy: claims.UserID,
		JoinedAt:   time.Now(),
	}

	if err := h.agentRepo.AddToOrg(c.Request.Context(), membership); err != nil {
		tx.Rollback()
		response.InternalError(c, "加入组织失败")
		return
	}

	tx.Commit()

	// 获取详细信息
	ag, _ := h.agentRepo.GetByID(c.Request.Context(), request.AgentID)
	org, _ := h.orgRepo.GetByID(c.Request.Context(), request.OrgID)

	response.Success(c, gin.H{
		"request_id": requestID,
		"status":     "approved",
		"agent": gin.H{
			"id":   ag.ID,
			"name": ag.Name,
		},
		"org": gin.H{
			"id":   org.ID,
			"name": org.Name,
		},
	})
}

// Reject 拒绝申请
func (h *JoinRequestHandler) Reject(c *gin.Context) {
	requestID := c.Param("id")
	claims, _ := c.Get("claims").(*jwt.Claims)

	var req struct {
		Reason string `json:"reason"`
	}
	c.ShouldBindJSON(&req)

	request, err := h.agentRepo.GetJoinRequestByID(c.Request.Context(), requestID)
	if err != nil {
		response.NotFound(c, "申请不存在")
		return
	}

	if request.Status != "pending" {
		response.BadRequest(c, 400001, "该申请已处理")
		return
	}

	// 验证是否为组织管理员
	role, err := h.orgRepo.GetMemberRole(c.Request.Context(), request.OrgID, claims.UserID)
	if err != nil || (role != "owner" && role != "admin") {
		response.Forbidden(c, "无权审批")
		return
	}

	if err := h.agentRepo.UpdateJoinRequestStatus(c.Request.Context(), requestID, "rejected"); err != nil {
		response.InternalError(c, "操作失败")
		return
	}

	response.Success(c, gin.H{
		"request_id": requestID,
		"status":     "rejected",
	})
}