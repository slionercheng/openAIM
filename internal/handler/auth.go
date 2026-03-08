package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/your-org/openim/internal/domain/user"
	"github.com/your-org/openim/internal/service"
	"github.com/your-org/openim/pkg/idgen"
	"github.com/your-org/openim/pkg/jwt"
	"github.com/your-org/openim/pkg/response"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/redis/go-redis/v9"
)

type AuthHandler struct {
	db         *gorm.DB
	rdb        *redis.Client
	jwtConfig  jwt.JWTConfig
	userRepo   user.Repository
	authService *service.AuthService
}

func NewAuthHandler(db *gorm.DB, rdb *redis.Client, jwtConfig jwt.JWTConfig) *AuthHandler {
	return &AuthHandler{
		db:        db,
		rdb:       rdb,
		jwtConfig: jwtConfig,
		userRepo:  user.NewRepository(db),
		authService: service.NewAuthService(db, jwtConfig),
	}
}

type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
	Name     string `json:"name" binding:"required,min=2,max=50"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
}

// Register 用户注册
func (h *AuthHandler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误: "+err.Error())
		return
	}

	// 检查邮箱是否已存在
	existingUser, _ := h.userRepo.GetByEmail(c.Request.Context(), req.Email)
	if existingUser != nil {
		response.Error(c, http.StatusConflict, 409001, "邮箱已被注册")
		return
	}

	// 加密密码
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		response.InternalError(c, "密码加密失败")
		return
	}

	// 创建用户
	newUser := &user.User{
		ID:       idgen.Generate(idgen.TypeUser),
		Email:    req.Email,
		Password: string(hashedPassword),
		Name:     req.Name,
		Status:   "active",
	}

	if err := h.userRepo.Create(c.Request.Context(), newUser); err != nil {
		response.InternalError(c, "创建用户失败")
		return
	}

	// 创建个人组织并注册
	result, err := h.authService.RegisterWithDefaultOrg(c.Request.Context(), newUser)
	if err != nil {
		response.InternalError(c, "注册失败: "+err.Error())
		return
	}

	response.Success(c, gin.H{
		"user": gin.H{
			"id":         result.User.ID,
			"email":      result.User.Email,
			"name":       result.User.Name,
			"created_at": result.User.CreatedAt,
		},
		"token": gin.H{
			"access_token":  result.AccessToken,
			"refresh_token": result.RefreshToken,
			"expires_in":    int64(h.jwtConfig.Expire.Seconds()),
		},
		"default_org": gin.H{
			"id":   result.DefaultOrg.ID,
			"name": result.DefaultOrg.Name,
			"type": result.DefaultOrg.Type,
		},
	})
}

// Login 用户登录
func (h *AuthHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误: "+err.Error())
		return
	}

	// 查找用户
	u, err := h.userRepo.GetByEmail(c.Request.Context(), req.Email)
	if err != nil {
		response.Error(c, http.StatusUnauthorized, 401001, "邮箱或密码错误")
		return
	}

	// 验证密码
	if err := bcrypt.CompareHashAndPassword([]byte(u.Password), []byte(req.Password)); err != nil {
		response.Error(c, http.StatusUnauthorized, 401001, "邮箱或密码错误")
		return
	}

	// 生成 Token
	accessToken, err := jwt.GenerateToken(u.ID, u.Email, "user", h.jwtConfig)
	if err != nil {
		response.InternalError(c, "生成Token失败")
		return
	}

	refreshToken, err := jwt.GenerateRefreshToken(u.ID, u.Email, "user", h.jwtConfig)
	if err != nil {
		response.InternalError(c, "生成RefreshToken失败")
		return
	}

	response.Success(c, gin.H{
		"user": gin.H{
			"id":    u.ID,
			"email": u.Email,
			"name":  u.Name,
		},
		"token": gin.H{
			"access_token":  accessToken,
			"refresh_token": refreshToken,
			"expires_in":    int64(h.jwtConfig.Expire.Seconds()),
		},
	})
}

// Logout 用户登出
func (h *AuthHandler) Logout(c *gin.Context) {
	// TODO: 将 token 加入黑名单
	response.Success(c, nil)
}

// RefreshToken 刷新 Token
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, 400001, "参数错误")
		return
	}

	claims, err := jwt.ParseToken(req.RefreshToken, h.jwtConfig.Secret)
	if err != nil {
		response.Unauthorized(c, "无效的refresh token")
		return
	}

	// 生成新的 access token
	accessToken, err := jwt.GenerateToken(claims.UserID, claims.Email, claims.Type, h.jwtConfig)
	if err != nil {
		response.InternalError(c, "生成Token失败")
		return
	}

	refreshToken, err := jwt.GenerateRefreshToken(claims.UserID, claims.Email, claims.Type, h.jwtConfig)
	if err != nil {
		response.InternalError(c, "生成RefreshToken失败")
		return
	}

	response.Success(c, gin.H{
		"access_token":  accessToken,
		"refresh_token": refreshToken,
		"expires_in":    int64(h.jwtConfig.Expire.Seconds()),
	})
}