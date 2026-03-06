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
	if client.UserType == "agent" {
		h.agentClients.Store(client.AgentID, client)
		// 更新 Agent 状态为 online
		h.db.Exec("UPDATE agents SET status = 'online' WHERE id = ?", client.AgentID)
		logger.Infof("Agent %s connected", client.AgentID)
	} else {
		h.userClients.Store(client.UserID, client)
		logger.Infof("User %s connected", client.UserID)
	}
}

func (h *Hub) unregisterClient(client *Client) {
	if client.UserType == "agent" {
		h.agentClients.Delete(client.AgentID)
		// 更新 Agent 状态为 offline
		h.db.Exec("UPDATE agents SET status = 'offline' WHERE id = ?", client.AgentID)
		logger.Infof("Agent %s disconnected", client.AgentID)
	} else {
		h.userClients.Delete(client.UserID)
		logger.Infof("User %s disconnected", client.UserID)
	}

	close(client.Send)
	client.Conn.Close()
}

// SendToUser 发送消息给指定用户
func (h *Hub) SendToUser(userID string, message interface{}) error {
	if client, ok := h.userClients.Load(userID); ok {
		c := client.(*Client)
		data, err := json.Marshal(message)
		if err != nil {
			return err
		}
		c.Send <- data
	}
	return nil
}

// SendToAgent 发送消息给指定 Agent
func (h *Hub) SendToAgent(agentID string, message interface{}) error {
	if client, ok := h.agentClients.Load(agentID); ok {
		c := client.(*Client)
		data, err := json.Marshal(message)
		if err != nil {
			return err
		}
		c.Send <- data
	}
	return nil
}

// BroadcastToConversation 广播消息给会话中的所有参与者
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

	for _, p := range participants {
		if p.ParticipantType == "user" && p.ParticipantID != excludeUserID {
			h.SendToUser(p.ParticipantID, data)
		} else if p.ParticipantType == "agent" {
			h.SendToAgent(p.ParticipantID, data)
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