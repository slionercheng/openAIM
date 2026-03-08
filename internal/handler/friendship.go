package handler

import (
	"net/url"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/your-org/openim/internal/domain/friendship"
	"github.com/your-org/openim/internal/domain/user"
	"github.com/your-org/openim/pkg/idgen"
	"github.com/your-org/openim/pkg/jwt"
	"github.com/your-org/openim/pkg/response"
	"gorm.io/gorm"
)

type FriendshipHandler struct {
	db             *gorm.DB
	friendshipRepo friendship.Repository
	userRepo       user.Repository
}

func NewFriendshipHandler(db *gorm.DB) *FriendshipHandler {
	return &FriendshipHandler{
		db:             db,
		friendshipRepo: friendship.NewRepository(db),
		userRepo:       user.NewRepository(db),
	}
}

// SearchUsersRequest 搜索用户请求参数
type SearchUsersRequest struct {
	Q        string `form:"q" binding:"required"`
	Page     int    `form:"page"`
	PageSize int    `form:"page_size"`
}

// SearchUsersResponse 搜索用户响应
type SearchUsersResponse struct {
	Total    int64                       `json:"total"`
	Page     int                         `json:"page"`
	PageSize int                         `json:"page_size"`
	Items    []SearchUserItem            `json:"items"`
}

// SearchUserItem 搜索用户结果项
type SearchUserItem struct {
	ID               string `json:"id"`
	Email            string `json:"email"`
	Name             string `json:"name"`
	Avatar           string `json:"avatar,omitempty"`
	Status           string `json:"status"`
	FriendshipStatus string `json:"friendship_status"`
}

// SearchUsers 搜索用户
// GET /api/v1/users/search
func (h *FriendshipHandler) SearchUsers(c *gin.Context) {
	claims := c.MustGet("claims").(*jwt.Claims)

	var req SearchUsersRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	// 设置默认值
	if req.Page <= 0 {
		req.Page = 1
	}
	if req.PageSize <= 0 {
		req.PageSize = 20
	}
	if req.PageSize > 50 {
		req.PageSize = 50
	}

	// URL 解码搜索关键词
	keyword, err := url.QueryUnescape(req.Q)
	if err != nil {
		keyword = req.Q
	}

	// 搜索用户
	users, total, err := h.userRepo.Search(c.Request.Context(), keyword, req.Page, req.PageSize)
	if err != nil {
		response.InternalError(c, "搜索用户失败")
		return
	}

	// 构建响应
	items := make([]SearchUserItem, 0, len(users))
	for _, u := range users {
		// 排除自己
		if u.ID == claims.UserID {
			continue
		}

		// 获取好友关系状态
		friendshipStatus, _ := h.friendshipRepo.GetFriendshipStatus(c.Request.Context(), claims.UserID, u.ID)

		items = append(items, SearchUserItem{
			ID:               u.ID,
			Email:            u.Email,
			Name:             u.Name,
			Avatar:           u.Avatar,
			Status:           u.Status,
			FriendshipStatus: friendshipStatus,
		})
	}

	response.Success(c, SearchUsersResponse{
		Total:    total,
		Page:     req.Page,
		PageSize: req.PageSize,
		Items:    items,
	})
}

// SendFriendRequest 发送好友请求
// POST /api/v1/friends/request
func (h *FriendshipHandler) SendFriendRequest(c *gin.Context) {
	claims := c.MustGet("claims").(*jwt.Claims)

	var req struct {
		UserID string `json:"user_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	// 不能添加自己为好友
	if req.UserID == claims.UserID {
		response.BadRequest(c, 400002, "不能添加自己为好友")
		return
	}

	// 检查目标用户是否存在
	targetUser, err := h.userRepo.GetByID(c.Request.Context(), req.UserID)
	if err != nil {
		response.NotFound(c, "用户不存在")
		return
	}

	// 检查是否已存在好友关系
	existingFriendship, err := h.friendshipRepo.GetByUserPair(c.Request.Context(), claims.UserID, req.UserID)
	if err != nil && err != gorm.ErrRecordNotFound {
		response.InternalError(c, "检查好友关系失败")
		return
	}

	if existingFriendship != nil {
		switch existingFriendship.Status {
		case friendship.FriendshipStatusPending:
			if existingFriendship.RequesterID == claims.UserID {
				response.BadRequest(c, 400003, "已发送好友请求，请等待对方处理")
			} else {
				response.BadRequest(c, 400003, "对方已发送好友请求，请先处理")
			}
			return
		case friendship.FriendshipStatusAccepted:
			response.BadRequest(c, 400003, "已经是好友了")
			return
		case friendship.FriendshipStatusBlocked:
			if existingFriendship.RequesterID == claims.UserID {
				// 自己拉黑了对方，不允许发送请求
				response.BadRequest(c, 400003, "您已拉黑该用户")
			} else {
				// 对方拉黑了自己
				response.BadRequest(c, 400003, "无法发送请求")
			}
			return
		case friendship.FriendshipStatusRejected:
			// 被拒绝后可以重新发送请求
			existingFriendship.Status = friendship.FriendshipStatusPending
			if existingFriendship.RequesterID == claims.UserID {
				if err := h.friendshipRepo.Update(c.Request.Context(), existingFriendship); err != nil {
					response.InternalError(c, "发送好友请求失败")
					return
				}
			} else {
				// 对方之前拒绝了自己，现在自己重新发送，需要反转方向
				existingFriendship.RequesterID = claims.UserID
				existingFriendship.AddresseeID = req.UserID
				if err := h.friendshipRepo.Update(c.Request.Context(), existingFriendship); err != nil {
					response.InternalError(c, "发送好友请求失败")
					return
				}
			}
			response.Success(c, gin.H{
				"id":            existingFriendship.ID,
				"requester_id":  existingFriendship.RequesterID,
				"addressee_id":  existingFriendship.AddresseeID,
				"status":        existingFriendship.Status,
				"created_at":    existingFriendship.CreatedAt,
				"target_user":   targetUser,
			})
			return
		}
	}

	// 创建新的好友请求
	newFriendship := &friendship.Friendship{
		ID:          idgen.Generate(idgen.TypeFriendReq),
		RequesterID: claims.UserID,
		AddresseeID: req.UserID,
		Status:      friendship.FriendshipStatusPending,
	}

	if err := h.friendshipRepo.Create(c.Request.Context(), newFriendship); err != nil {
		response.InternalError(c, "发送好友请求失败")
		return
	}

	response.SuccessWithMessage(c, "好友请求已发送", gin.H{
		"id":            newFriendship.ID,
		"requester_id":  newFriendship.RequesterID,
		"addressee_id":  newFriendship.AddresseeID,
		"status":        newFriendship.Status,
		"created_at":    newFriendship.CreatedAt,
		"target_user":   targetUser,
	})
}

// GetFriends 获取好友列表
// GET /api/v1/friends
func (h *FriendshipHandler) GetFriends(c *gin.Context) {
	claims := c.MustGet("claims").(*jwt.Claims)

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 || pageSize > 50 {
		pageSize = 20
	}

	friendships, total, err := h.friendshipRepo.GetFriends(c.Request.Context(), claims.UserID, page, pageSize)
	if err != nil {
		response.InternalError(c, "获取好友列表失败")
		return
	}

	// 构建响应，获取好友用户信息
	items := make([]gin.H, 0, len(friendships))
	for _, f := range friendships {
		// 确定好友ID（对方）
		friendID := f.AddresseeID
		if f.AddresseeID == claims.UserID {
			friendID = f.RequesterID
		}

		// 获取好友用户信息
		friendUser, err := h.userRepo.GetByID(c.Request.Context(), friendID)
		if err != nil {
			continue
		}

		items = append(items, gin.H{
			"id":         f.ID,
			"user": gin.H{
				"id":     friendUser.ID,
				"email":  friendUser.Email,
				"name":   friendUser.Name,
				"avatar": friendUser.Avatar,
				"status": friendUser.Status,
			},
			"created_at": f.CreatedAt,
		})
	}

	response.Success(c, gin.H{
		"total":     total,
		"page":      page,
		"page_size": pageSize,
		"items":     items,
	})
}

// GetFriendRequests 获取好友请求列表
// GET /api/v1/friends/requests
func (h *FriendshipHandler) GetFriendRequests(c *gin.Context) {
	claims := c.MustGet("claims").(*jwt.Claims)

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	status := friendship.FriendshipStatus(c.DefaultQuery("status", string(friendship.FriendshipStatusPending)))

	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 || pageSize > 50 {
		pageSize = 20
	}

	friendships, total, err := h.friendshipRepo.GetFriendRequests(c.Request.Context(), claims.UserID, status, page, pageSize)
	if err != nil {
		response.InternalError(c, "获取好友请求失败")
		return
	}

	// 构建响应，获取请求者用户信息
	items := make([]gin.H, 0, len(friendships))
	for _, f := range friendships {
		// 获取请求者用户信息
		requester, err := h.userRepo.GetByID(c.Request.Context(), f.RequesterID)
		if err != nil {
			continue
		}

		items = append(items, gin.H{
			"id": f.ID,
			"requester": gin.H{
				"id":     requester.ID,
				"email":  requester.Email,
				"name":   requester.Name,
				"avatar": requester.Avatar,
			},
			"status":     f.Status,
			"created_at": f.CreatedAt,
		})
	}

	response.Success(c, gin.H{
		"total":     total,
		"page":      page,
		"page_size": pageSize,
		"items":     items,
	})
}

// AcceptFriendRequest 接受好友请求
// POST /api/v1/friends/requests/:id/accept
func (h *FriendshipHandler) AcceptFriendRequest(c *gin.Context) {
	claims := c.MustGet("claims").(*jwt.Claims)
	friendshipID := c.Param("id")

	// 获取好友请求
	f, err := h.friendshipRepo.GetByID(c.Request.Context(), friendshipID)
	if err != nil {
		response.NotFound(c, "好友请求不存在")
		return
	}

	// 验证当前用户是接收者
	if f.AddresseeID != claims.UserID {
		response.Forbidden(c, "无权处理此请求")
		return
	}

	// 验证状态
	if f.Status != friendship.FriendshipStatusPending {
		response.BadRequest(c, 400004, "该请求已处理")
		return
	}

	// 更新状态
	f.Status = friendship.FriendshipStatusAccepted
	if err := h.friendshipRepo.Update(c.Request.Context(), f); err != nil {
		response.InternalError(c, "接受好友请求失败")
		return
	}

	response.SuccessWithMessage(c, "已接受好友请求", gin.H{
		"id":         f.ID,
		"status":     f.Status,
		"updated_at": f.UpdatedAt,
	})
}

// RejectFriendRequest 拒绝好友请求
// POST /api/v1/friends/requests/:id/reject
func (h *FriendshipHandler) RejectFriendRequest(c *gin.Context) {
	claims := c.MustGet("claims").(*jwt.Claims)
	friendshipID := c.Param("id")

	// 获取好友请求
	f, err := h.friendshipRepo.GetByID(c.Request.Context(), friendshipID)
	if err != nil {
		response.NotFound(c, "好友请求不存在")
		return
	}

	// 验证当前用户是接收者
	if f.AddresseeID != claims.UserID {
		response.Forbidden(c, "无权处理此请求")
		return
	}

	// 验证状态
	if f.Status != friendship.FriendshipStatusPending {
		response.BadRequest(c, 400004, "该请求已处理")
		return
	}

	// 更新状态
	f.Status = friendship.FriendshipStatusRejected
	if err := h.friendshipRepo.Update(c.Request.Context(), f); err != nil {
		response.InternalError(c, "拒绝好友请求失败")
		return
	}

	response.SuccessWithMessage(c, "已拒绝好友请求", gin.H{
		"id":         f.ID,
		"status":     f.Status,
		"updated_at": f.UpdatedAt,
	})
}

// DeleteFriend 删除好友
// DELETE /api/v1/friends/:id
func (h *FriendshipHandler) DeleteFriend(c *gin.Context) {
	claims := c.MustGet("claims").(*jwt.Claims)
	friendshipID := c.Param("id")

	// 获取好友关系
	f, err := h.friendshipRepo.GetByID(c.Request.Context(), friendshipID)
	if err != nil {
		response.NotFound(c, "好友关系不存在")
		return
	}

	// 验证当前用户是好友关系的一方
	if f.RequesterID != claims.UserID && f.AddresseeID != claims.UserID {
		response.Forbidden(c, "无权删除此好友")
		return
	}

	// 验证状态
	if f.Status != friendship.FriendshipStatusAccepted {
		response.BadRequest(c, 400005, "不是好友关系")
		return
	}

	// 删除好友关系
	if err := h.friendshipRepo.Delete(c.Request.Context(), friendshipID); err != nil {
		response.InternalError(c, "删除好友失败")
		return
	}

	response.SuccessWithMessage(c, "已删除好友", nil)
}

// GetPendingRequestCount 获取待处理好友请求数量
// GET /api/v1/friends/requests/count
func (h *FriendshipHandler) GetPendingRequestCount(c *gin.Context) {
	claims := c.MustGet("claims").(*jwt.Claims)

	count, err := h.friendshipRepo.CountPendingRequests(c.Request.Context(), claims.UserID)
	if err != nil {
		response.InternalError(c, "获取数量失败")
		return
	}

	response.Success(c, gin.H{
		"count": count,
	})
}