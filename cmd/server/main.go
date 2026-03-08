package main

import (
	"log"

	"github.com/your-org/openim/internal/middleware"
	"github.com/your-org/openim/internal/handler"
	"github.com/your-org/openim/internal/ws"
	"github.com/your-org/openim/pkg/config"
	"github.com/your-org/openim/pkg/database"
	"github.com/your-org/openim/pkg/logger"
	"github.com/your-org/openim/pkg/redis"

	"github.com/gin-gonic/gin"
)

func main() {
	// 加载配置
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// 初始化日志
	logger.Init(cfg.Log)

	// 初始化数据库
	db, err := database.Init(cfg.Database)
	if err != nil {
		log.Fatalf("Failed to connect database: %v", err)
	}

	// 自动迁移
	if err := database.Migrate(db); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	// 初始化 Redis
	rdb, err := redis.Init(cfg.Redis)
	if err != nil {
		log.Fatalf("Failed to connect redis: %v", err)
	}

	// 初始化 Gin
	if cfg.App.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}
	r := gin.Default()

	// 注册中间件
	r.Use(middleware.CORS())
	r.Use(middleware.RateLimit(rdb))

	// 注册路由
	api := r.Group("/api/v1")
	{
		// 认证路由
		authHandler := handler.NewAuthHandler(db, rdb, cfg.JWT)
		auth := api.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
			auth.POST("/logout", authHandler.Logout)
			auth.POST("/refresh", authHandler.RefreshToken)
		}

		// 需要认证的路由
		protected := api.Group("")
		protected.Use(middleware.Auth(cfg.JWT))
		{
			// 用户路由
			userHandler := handler.NewUserHandler(db)
			friendshipHandler := handler.NewFriendshipHandler(db)
			users := protected.Group("/users")
			{
				users.GET("/me", userHandler.GetCurrentUser)
				users.PUT("/me", userHandler.UpdateUser)
				users.GET("/me/orgs", userHandler.GetUserOrganizations)
				users.GET("/me/agents", userHandler.GetUserAgents)
				users.GET("/search", friendshipHandler.SearchUsers)
			}

			// 好友路由
			friends := protected.Group("/friends")
			{
				friends.GET("", friendshipHandler.GetFriends)
				friends.GET("/requests", friendshipHandler.GetFriendRequests)
				friends.GET("/requests/count", friendshipHandler.GetPendingRequestCount)
				friends.POST("/request", friendshipHandler.SendFriendRequest)
				friends.POST("/requests/:id/accept", friendshipHandler.AcceptFriendRequest)
				friends.POST("/requests/:id/reject", friendshipHandler.RejectFriendRequest)
				friends.DELETE("/:id", friendshipHandler.DeleteFriend)
			}

			// 组织路由
			orgHandler := handler.NewOrganizationHandler(db)
			orgs := protected.Group("/organizations")
			{
				orgs.POST("", orgHandler.Create)
				orgs.GET("/:id", orgHandler.GetByID)
				orgs.PUT("/:id", orgHandler.Update)
				orgs.DELETE("/:id", orgHandler.Delete)
				orgs.GET("/:id/members", orgHandler.GetMembers)
				orgs.POST("/:id/invitations", orgHandler.InviteMember)
				orgs.GET("/:id/agents", orgHandler.GetAgents)
				orgs.PUT("/:id/members/:user_id", orgHandler.UpdateMemberRole)
				orgs.DELETE("/:id/members/:user_id", orgHandler.RemoveMember)
			}

			// Agent 路由
			agentHandler := handler.NewAgentHandler(db, cfg.JWT)
			agents := protected.Group("/agents")
			{
				agents.POST("", agentHandler.Create)
				agents.GET("/:id", agentHandler.GetByID)
				agents.PUT("/:id", agentHandler.Update)
				agents.DELETE("/:id", agentHandler.Delete)
				agents.POST("/:id/join-requests", agentHandler.CreateJoinRequest)
				agents.GET("/:id/join-requests", agentHandler.GetJoinRequests)
				agents.POST("/:id/regenerate-token", agentHandler.RegenerateToken)
			}

			// 加入申请路由
			joinRequestHandler := handler.NewJoinRequestHandler(db)
			joinRequests := protected.Group("/join-requests")
			{
				joinRequests.GET("", joinRequestHandler.List)
				joinRequests.POST("/:id/approve", joinRequestHandler.Approve)
				joinRequests.POST("/:id/reject", joinRequestHandler.Reject)
			}

			// 会话路由
			convHandler := handler.NewConversationHandler(db)
			conversations := protected.Group("/conversations")
			{
				conversations.POST("", convHandler.Create)
				conversations.GET("", convHandler.List)
				conversations.GET("/:id", convHandler.GetByID)
				conversations.PUT("/:id", convHandler.Update)
				conversations.DELETE("/:id", convHandler.Delete)
				conversations.POST("/:id/participants", convHandler.AddParticipant)
				conversations.DELETE("/:id/participants/:pid", convHandler.RemoveParticipant)
			}

			// 消息路由
			msgHandler := handler.NewMessageHandler(db, rdb)
			messages := protected.Group("/conversations/:id/messages")
			{
				messages.GET("", msgHandler.List)
				messages.POST("", msgHandler.Send)
			}
		}
	}

	// WebSocket 路由
	hub := ws.NewHub(db, rdb)
	go hub.Run()
	r.GET("/ws", func(c *gin.Context) {
		ws.ServeWebSocket(hub, c, cfg.JWT)
	})

	// 健康检查
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// 启动服务
	logger.Info("Server starting on :" + cfg.App.Port)
	if err := r.Run(":" + cfg.App.Port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}