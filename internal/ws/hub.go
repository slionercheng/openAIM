package ws

import (
	"encoding/json"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/your-org/openim/pkg/jwt"
	"github.com/your-org/openim/pkg/logger"
	"gorm.io/gorm"

	"github.com/redis/go-redis/v9"
)

// Client 表示一个 WebSocket 客户端连接
type Client struct {
	Hub         *Hub
	Conn        *websocket.Conn
	Send        chan []byte
	UserID      string
	UserType    string // "user" or "agent"
	AgentID     string // 如果是 agent 连接
	closed      bool   // 是否已关闭
	closedMutex sync.Mutex
}

// Hub 管理所有客户端连接
type Hub struct {
	db         *gorm.DB
	rdb        *redis.Client
	jwtConfig  jwt.JWTConfig

	// 用户连接: userID -> *Client
	userClients sync.Map

	// Agent 连接: agentID -> *Client
	agentClients sync.Map

	// 注册通道
	register chan *Client

	// 注销通道
	unregister chan *Client
}

func NewHub(db *gorm.DB, rdb *redis.Client) *Hub {
	return &Hub{
		db:         db,
		rdb:        rdb,
		register:   make(chan *Client, 256),
		unregister: make(chan *Client, 256),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.registerClient(client)

		case client := <-h.unregister:
			h.unregisterClient(client)
		}
	}
}

func (h *Hub) registerClient(client *Client) {
	// 检查是否已有相同用户在线
	if client.UserType == "agent" {
		if _, ok := h.agentClients.Load(client.AgentID); ok {
			// 已在线，通知新客户端需要确认
			logger.Infof("Agent %s already online, asking for confirmation", client.AgentID)
			client.Send <- []byte(`{"type":"already_online","user_type":"agent","user_id":"` + client.AgentID + `"}`)
			// 不注册，等待确认
			return
		}
		h.agentClients.Store(client.AgentID, client)
		// 更新 Agent 状态为 online
		h.db.Exec("UPDATE agents SET status = 'online' WHERE id = ?", client.AgentID)
		logger.Infof("Agent %s connected", client.AgentID)
	} else {
		if _, ok := h.userClients.Load(client.UserID); ok {
			// 已在线，通知新客户端需要确认
			logger.Infof("User %s already online, asking for confirmation", client.UserID)
			client.Send <- []byte(`{"type":"already_online","user_type":"user","user_id":"` + client.UserID + `"}`)
			// 不注册，等待确认
			return
		}
		h.userClients.Store(client.UserID, client)
		logger.Infof("User %s connected", client.UserID)
	}

	// 推送离线消息
	h.deliverPendingMessages(client)
}

// ForceLogin 处理强制登录确认
func (h *Hub) ForceLogin(client *Client) {
	if client.UserType == "agent" {
		if existingClient, ok := h.agentClients.Load(client.AgentID); ok {
			c := existingClient.(*Client)
			logger.Infof("Agent %s force login, kicking old connection", client.AgentID)
			// 发送被踢下线的通知
			c.Send <- []byte(`{"type":"kicked","reason":"duplicate_login"}`)
			// 标记为已关闭并关闭旧连接
			c.close()
			h.agentClients.Delete(client.AgentID)
		}
		h.agentClients.Store(client.AgentID, client)
		// 更新 Agent 状态为 online
		h.db.Exec("UPDATE agents SET status = 'online' WHERE id = ?", client.AgentID)
		logger.Infof("Agent %s force login connected", client.AgentID)
	} else {
		if existingClient, ok := h.userClients.Load(client.UserID); ok {
			c := existingClient.(*Client)
			logger.Infof("User %s force login, kicking old connection", client.UserID)
			// 发送被踢下线的通知
			c.Send <- []byte(`{"type":"kicked","reason":"duplicate_login"}`)
			// 标记为已关闭并关闭旧连接
			c.close()
			h.userClients.Delete(client.UserID)
		}
		h.userClients.Store(client.UserID, client)
		logger.Infof("User %s force login connected", client.UserID)
	}

	// 发送登录成功确认
	client.Send <- []byte(`{"type":"login_success"}`)

	// 推送离线消息
	h.deliverPendingMessages(client)
}

func (h *Hub) unregisterClient(client *Client) {
	// 检查是否已被关闭（被踢下线的情况）
	client.closedMutex.Lock()
	if client.closed {
		client.closedMutex.Unlock()
		return
	}
	client.closed = true
	client.closedMutex.Unlock()

	if client.UserType == "agent" {
		// 只有当这个 client 是实际存储的那个时才删除
		if stored, ok := h.agentClients.Load(client.AgentID); ok && stored == client {
			h.agentClients.Delete(client.AgentID)
			// 更新 Agent 状态为 offline
			h.db.Exec("UPDATE agents SET status = 'offline' WHERE id = ?", client.AgentID)
			logger.Infof("Agent %s disconnected", client.AgentID)
		} else {
			logger.Infof("Agent %s unregistered (was not the active connection)", client.AgentID)
		}
	} else {
		// 只有当这个 client 是实际存储的那个时才删除
		if stored, ok := h.userClients.Load(client.UserID); ok && stored == client {
			h.userClients.Delete(client.UserID)
			logger.Infof("User %s disconnected", client.UserID)
		} else {
			logger.Infof("User %s unregistered (was not the active connection)", client.UserID)
		}
	}

	close(client.Send)
	client.Conn.Close()
}

// close 关闭客户端连接（内部方法，确保只关闭一次）
func (c *Client) close() {
	c.closedMutex.Lock()
	defer c.closedMutex.Unlock()

	if c.closed {
		return
	}
	c.closed = true

	close(c.Send)
	c.Conn.Close()
}

// IsUserOnline 检查用户是否在线
func (h *Hub) IsUserOnline(userID string) bool {
	_, ok := h.userClients.Load(userID)
	return ok
}

// IsAgentOnline 检查 Agent 是否在线
func (h *Hub) IsAgentOnline(agentID string) bool {
	_, ok := h.agentClients.Load(agentID)
	return ok
}

// GetOnlineUsers 获取所有在线用户ID
func (h *Hub) GetOnlineUsers() []string {
	var userIDs []string
	h.userClients.Range(func(key, value interface{}) bool {
		if userID, ok := key.(string); ok {
			userIDs = append(userIDs, userID)
		}
		return true
	})
	return userIDs
}

// SendToUser 发送消息给指定用户
func (h *Hub) SendToUser(userID string, message interface{}) error {
	if client, ok := h.userClients.Load(userID); ok {
		c := client.(*Client)
		var data []byte
		var err error

		// 如果已经是 []byte，直接使用
		if b, ok := message.([]byte); ok {
			data = b
		} else {
			data, err = json.Marshal(message)
			if err != nil {
				return err
			}
		}
		logger.Infof("Sending message to user %s: %s", userID, string(data))
		c.Send <- data
	} else {
		logger.Warnf("User %s not connected, cannot send message", userID)
	}
	return nil
}

// SendToAgent 发送消息给指定 Agent
func (h *Hub) SendToAgent(agentID string, message interface{}) error {
	if client, ok := h.agentClients.Load(agentID); ok {
		c := client.(*Client)
		var data []byte
		var err error

		// 如果已经是 []byte，直接使用
		if b, ok := message.([]byte); ok {
			data = b
		} else {
			data, err = json.Marshal(message)
			if err != nil {
				return err
			}
		}
		c.Send <- data
	}
	return nil
}

// BroadcastToConversation 广播消息给会话中的所有参与者（带离线缓存）
func (h *Hub) BroadcastToConversation(conversationID string, message interface{}, excludeUserID string) error {
	// 获取会话参与者
	var participants []struct {
		ParticipantType string
		ParticipantID   string
	}

	h.db.Table("participants").
		Where("conversation_id = ?", conversationID).
		Select("participant_type, participant_id").
		Find(&participants)

	data, err := json.Marshal(message)
	if err != nil {
		return err
	}

	logger.Infof("Broadcasting to conversation %s, excluding %s, participants: %+v", conversationID, excludeUserID, participants)

	for _, p := range participants {
		if p.ParticipantType == "user" && p.ParticipantID != excludeUserID {
			logger.Infof("Sending to user %s", p.ParticipantID)
			// 使用带缓存的方法
			h.sendToUserWithCache(p.ParticipantID, data)
		} else if p.ParticipantType == "agent" {
			logger.Infof("Sending to agent %s", p.ParticipantID)
			// 使用带缓存的方法
			h.sendToAgentWithCache(p.ParticipantID, data)
		}
	}

	return nil
}

// ReadPump 从客户端读取消息
func (c *Client) ReadPump() {
	defer func() {
		c.Hub.unregister <- c
	}()

	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			break
		}

		// 处理消息
		c.handleMessage(message)
	}
}

// WritePump 向客户端发送消息
func (c *Client) WritePump() {
	defer func() {
		c.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.Send:
			if !ok {
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			c.Conn.WriteMessage(websocket.TextMessage, message)
		}
	}
}

type WSMessage struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}

func (c *Client) handleMessage(data []byte) {
	var msg WSMessage
	if err := json.Unmarshal(data, &msg); err != nil {
		logger.Errorf("Failed to parse message: %v", err)
		return
	}

	switch msg.Type {
	case "heartbeat":
		c.Send <- []byte(`{"type":"pong"}`)

	case "message":
		c.handleChatMessage(msg.Data)

	case "force_login":
		c.Hub.ForceLogin(c)

	default:
		logger.Warnf("Unknown message type: %s", msg.Type)
	}
}

type ChatMessage struct {
	ConversationID string `json:"conversation_id"`
	Content        string `json:"content"`
	ContentType    string `json:"content_type"`
}

func (c *Client) handleChatMessage(data json.RawMessage) {
	var msg ChatMessage
	if err := json.Unmarshal(data, &msg); err != nil {
		logger.Errorf("Failed to parse chat message: %v", err)
		return
	}

	// TODO: 存储消息并广播
	logger.Infof("Received message from %s: %s", c.UserID, msg.Content)
}