package ws

import (
	"context"
	"encoding/json"
	"time"

	"github.com/your-org/openim/pkg/logger"
)

const (
	// 离线消息缓存 key 前缀
	pendingMessagesPrefix = "openim:pending_messages:"
	// 离线消息过期时间（7天）
	pendingMessageTTL = 7 * 24 * time.Hour
)

// PendingMessage 待推送的离线消息
type PendingMessage struct {
	ID             string `json:"id"`
	ConversationID string `json:"conversation_id"`
	SenderType     string `json:"sender_type"`
	SenderID       string `json:"sender_id"`
	SenderName     string `json:"sender_name"`
	SenderAvatar   string `json:"sender_avatar"`
	Content        string `json:"content"`
	ContentType    string `json:"content_type"`
	CreatedAt      string `json:"created_at"`
	Type           string `json:"type"`
}

// cachePendingMessage 将消息缓存到 Redis（当用户离线时）
func (h *Hub) cachePendingMessage(userID string, message []byte) error {
	ctx := context.Background()
	key := pendingMessagesPrefix + userID

	// 将消息添加到列表
	err := h.rdb.RPush(ctx, key, message).Err()
	if err != nil {
		logger.Errorf("Failed to cache pending message for user %s: %v", userID, err)
		return err
	}

	// 设置过期时间
	h.rdb.Expire(ctx, key, pendingMessageTTL)

	logger.Infof("Cached pending message for offline user %s", userID)
	return nil
}

// deliverPendingMessages 推送离线消息（当用户上线时）
func (h *Hub) deliverPendingMessages(client *Client) {
	ctx := context.Background()
	var key string

	if client.UserType == "agent" {
		key = pendingMessagesPrefix + "agent:" + client.AgentID
	} else {
		key = pendingMessagesPrefix + client.UserID
	}

	// 获取所有待推送的消息
	messages, err := h.rdb.LRange(ctx, key, 0, -1).Result()
	if err != nil {
		logger.Errorf("Failed to get pending messages: %v", err)
		return
	}

	if len(messages) == 0 {
		return
	}

	logger.Infof("Delivering %d pending messages to user %s", len(messages), client.UserID)

	// 逐个推送消息
	for _, msgStr := range messages {
		select {
		case client.Send <- []byte(msgStr):
			// 发送成功
		default:
			// 发送缓冲区满，跳过
			logger.Warnf("Client send buffer full, skipping message")
		}
	}

	// 清除已推送的消息
	h.rdb.Del(ctx, key)
}

// SendToUser 发送消息给指定用户（带离线缓存）
func (h *Hub) sendToUserWithCache(userID string, message []byte) {
	logger.Infof("sendToUserWithCache: checking if user %s is online", userID)

	// 打印当前所有在线用户
	var onlineUsers []string
	h.userClients.Range(func(key, value interface{}) bool {
		if uid, ok := key.(string); ok {
			onlineUsers = append(onlineUsers, uid)
		}
		return true
	})
	logger.Infof("Currently online users: %v", onlineUsers)

	if client, ok := h.userClients.Load(userID); ok {
		c := client.(*Client)
		logger.Infof("User %s is online, sending message directly", userID)
		select {
		case c.Send <- message:
			logger.Infof("Message sent to user %s successfully", userID)
		default:
			logger.Warnf("User %s send buffer full, caching message", userID)
			h.cachePendingMessage(userID, message)
		}
	} else {
		// 用户离线，缓存消息
		logger.Infof("User %s NOT in userClients, caching message", userID)
		h.cachePendingMessage(userID, message)
	}
}

// SendToAgent 发送消息给指定 Agent（带离线缓存）
func (h *Hub) sendToAgentWithCache(agentID string, message []byte) {
	if client, ok := h.agentClients.Load(agentID); ok {
		c := client.(*Client)
		logger.Infof("Sending message to online agent %s", agentID)
		c.Send <- message
	} else {
		// Agent 离线，缓存消息
		logger.Infof("Agent %s offline, caching message", agentID)
		h.cachePendingMessage("agent:"+agentID, message)
	}
}

// GetPendingMessageCount 获取用户待推送消息数量
func (h *Hub) GetPendingMessageCount(userID string) int64 {
	ctx := context.Background()
	key := pendingMessagesPrefix + userID
	count, _ := h.rdb.LLen(ctx, key).Result()
	return count
}

// MarshalPendingMessage 将消息序列化为待推送格式
func MarshalPendingMessage(msg PendingMessage) ([]byte, error) {
	msg.Type = "new_message"
	return json.Marshal(msg)
}