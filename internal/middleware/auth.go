package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/your-org/openim/pkg/jwt"
	"github.com/your-org/openim/pkg/response"
)

// Auth JWT 认证中间件
func Auth(jwtConfig jwt.JWTConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			response.Unauthorized(c, "未提供认证信息")
			c.Abort()
			return
		}

		// Bearer token
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			response.Unauthorized(c, "认证格式错误")
			c.Abort()
			return
		}

		token := parts[1]
		claims, err := jwt.ParseToken(token, jwtConfig.Secret)
		if err != nil {
			response.Unauthorized(c, "Token 无效或已过期")
			c.Abort()
			return
		}

		// 将用户信息存入上下文
		c.Set("claims", claims)
		c.Set("user_id", claims.UserID)
		c.Set("user_type", claims.Type)

		c.Next()
	}
}