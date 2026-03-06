package middleware

import (
	"time"

	"github.com/gin-gonic/gin"
)

// CORS 跨域中间件
func CORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

// RateLimit 简单的限流中间件
func RateLimit(rdb interface{}) gin.HandlerFunc {
	// TODO: 实现基于 Redis 的限流
	return func(c *gin.Context) {
		// 简单实现，后续可以改用 Redis 实现
		c.Next()
	}
}

// Logger 日志中间件
func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()

		if status >= 400 {
			gin.DefaultWriter.Write([]byte("[WARN] "))
		}
		gin.DefaultWriter.Write([]byte(
			"[" + time.Now().Format("2006/01/02 - 15:04:05") + "] " +
			c.Request.Method + " " +
			path + " " +
			string(rune(status)) + " " +
			latency.String() + "\n",
		))
	}
}