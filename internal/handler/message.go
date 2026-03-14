package handler

import (
	"time"

	"github.com/gin-gonic/gin"
	"github.com/your-org/openim/internal/domain/conversation"
	"github.com/your-org/openim/internal/domain/message"
	"github.com/your-org/openim/internal/ws"
	"github.com/your-org/openim/pkg/idgen"
	"github.com/your-org/openim/pkg/jwt"
	"github.com/your-org/openim/pkg/response"
	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

type MessageHandler struct {
	db       *gorm.DB
	msgRepo  message.Repository
	convRepo conversation.Repository
	rdb      *redis.Client
	hub      *ws.Hub
}

func NewMessageHandler(db *gorm.DB, rdb *redis.Client, hub *ws.Hub) *MessageHandler {
	return &MessageHandler{
		db:       db,
		msgRepo:  message.NewRepository(db),
		convRepo: conversation.NewRepository(db),
		rdb:      rdb,
		hub:      hub,
	}
}

type SendMessageRequest struct {
	Content     string `json:"content" binding:"required"`
	ContentType string `json:"content_type"` // text, markdown, json
}

// List 获取消息历史
func (h *MessageHandler) List(c *gin.Context) {
	convID := c.Param("id")
	claims := c.MustGet("claims").(*jwt.Claims)

	// 验证用户是否是参与者
	isParticipant, err := h.convRepo.IsParticipant(c.Request.Context(), convID, "user", claims.UserID)
	if err != nil || !isParticipant {
		response.Forbidden(c, "无权访问")
		return
	}

	// 分页参数
	page := 1
	pageSize := 50
	if p := c.Query("page"); p != "" {
		c.ShouldBindQuery(&struct {
			Page int `form:"page"`
		}{Page: page})
	}

	messages, total, err := h.msgRepo.GetByConversationID(
		c.Request.Context(),
		convID,
		pageSize,
		(page-1)*pageSize,
	)

	if err != nil {
		response.InternalError(c, "获取消息失败")
		return
	}

	// 反转顺序（最新的在最后）
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}

	// 补充发送者信息
	result := make([]gin.H, len(messages))
	for i, msg := range messages {
		var senderName, senderAvatar string
		if msg.SenderType == "user" {
			h.db.Table("users").Where("id = ?", msg.SenderID).
				Select("name, avatar").Row().Scan(&senderName, &senderAvatar)
		} else {
			h.db.Table("agents").Where("id = ?", msg.SenderID).
				Select("name, avatar").Row().Scan(&senderName, &senderAvatar)
		}

		result[i] = gin.H{
			"id":           msg.ID,
			"sender_type":  msg.SenderType,
			"sender_id":    msg.SenderID,
			"sender_name":  senderName,
			"sender_avatar": senderAvatar,
			"content":      msg.Content,
			"content_type": msg.ContentType,
			"created_at":   msg.CreatedAt,
		}
	}

	response.SuccessPage(c, result, total, page, pageSize)
}

// Send 发送消息
func (h *MessageHandler) Send(c *gin.Context) {
	convID := c.Param("id")
	claims := c.MustGet("claims").(*jwt.Claims)

	var req SendMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	// 验证用户是否是参与者
	isParticipant, err := h.convRepo.IsParticipant(c.Request.Context(), convID, "user", claims.UserID)
	if err != nil || !isParticipant {
		response.Forbidden(c, "无权发送消息")
		return
	}

	contentType := req.ContentType
	if contentType == "" {
		contentType = "text"
	}

	msg := &message.Message{
		ID:             idgen.Generate(idgen.TypeMessage),
		ConversationID: convID,
		SenderType:     "user",
		SenderID:       claims.UserID,
		Content:        req.Content,
		ContentType:    contentType,
	}

	if err := h.msgRepo.Create(c.Request.Context(), msg); err != nil {
		response.InternalError(c, "发送失败")
		return
	}

	// 更新会话更新时间
	h.db.Exec("UPDATE conversations SET updated_at = ? WHERE id = ?", time.Now(), convID)

	// 获取发送者信息
	var senderName, senderAvatar string
	h.db.Table("users").Where("id = ?", claims.UserID).
		Select("name, avatar").Row().Scan(&senderName, &senderAvatar)

	// 构造消息数据
	messageData := gin.H{
		"type":           "new_message",
		"id":             msg.ID,
		"conversation_id": msg.ConversationID,
		"sender_type":    msg.SenderType,
		"sender_id":      msg.SenderID,
		"sender_name":    senderName,
		"sender_avatar":  senderAvatar,
		"content":        msg.Content,
		"content_type":   msg.ContentType,
		"created_at":     msg.CreatedAt,
	}

	// 通过 WebSocket 推送给其他参与者
	if h.hub != nil {
		h.hub.BroadcastToConversation(convID, messageData, claims.UserID)
	}

	response.Success(c, gin.H{
		"id":             msg.ID,
		"conversation_id": msg.ConversationID,
		"sender_type":     msg.SenderType,
		"sender_id":       msg.SenderID,
		"content":         msg.Content,
		"content_type":    msg.ContentType,
		"created_at":      msg.CreatedAt,
	})
}