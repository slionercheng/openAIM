package ws

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"github.com/your-org/openim/pkg/jwt"
	"github.com/your-org/openim/pkg/logger"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // 允许所有来源，生产环境需要限制
	},
}

// ServeWebSocket 处理 WebSocket 连接
func ServeWebSocket(hub *Hub, c *gin.Context, jwtConfig jwt.JWTConfig) {
	// 从查询参数获取 token
	token := c.Query("token")
	if token == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "token required"})
		return
	}

	// 验证 token
	claims, err := jwt.ParseToken(token, jwtConfig.Secret)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
		return
	}

	// 升级为 WebSocket 连接
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		logger.Errorf("WebSocket upgrade failed: %v", err)
		return
	}

	client := &Client{
		Hub:      hub,
		Conn:     conn,
		Send:     make(chan []byte, 256),
		UserID:   claims.UserID,
		UserType: claims.Type,
	}

	if claims.Type == "agent" {
		client.AgentID = claims.UserID
	}

	// 注册客户端
	hub.register <- client

	// 发送认证成功消息
	client.Send <- []byte(`{"type":"auth_success","user_id":"` + claims.UserID + `"}`)

	// 启动读写协程
	go client.WritePump()
	go client.ReadPump()
}