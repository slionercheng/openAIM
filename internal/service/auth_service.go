package service

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/your-org/openim/internal/domain/organization"
	"github.com/your-org/openim/internal/domain/user"
	"github.com/your-org/openim/pkg/jwt"
	"gorm.io/gorm"
)

type AuthService struct {
	db        *gorm.DB
	userRepo  user.Repository
	orgRepo   organization.Repository
	jwtConfig jwt.JWTConfig
}

type RegisterResult struct {
	User         *user.User
	AccessToken  string
	RefreshToken string
	DefaultOrg   *organization.Organization
}

func NewAuthService(db *gorm.DB, jwtConfig jwt.JWTConfig) *AuthService {
	return &AuthService{
		db:        db,
		userRepo:  user.NewRepository(db),
		orgRepo:   organization.NewRepository(db),
		jwtConfig: jwtConfig,
	}
}

// RegisterWithDefaultOrg 注册用户并创建默认个人组织
func (s *AuthService) RegisterWithDefaultOrg(ctx context.Context, u *user.User) (*RegisterResult, error) {
	tx := s.db.Begin()

	// 确保用户已创建
	if u.ID == "" {
		if err := s.userRepo.Create(ctx, u); err != nil {
			tx.Rollback()
			return nil, err
		}
	}

	// 创建个人组织
	defaultOrg := &organization.Organization{
		ID:      "org_" + uuid.New().String()[:8],
		Name:    u.Name + "的个人空间",
		Type:    "personal",
		OwnerID: u.ID,
	}

	if err := tx.Create(defaultOrg).Error; err != nil {
		tx.Rollback()
		return nil, err
	}

	// 用户加入个人组织
	membership := &organization.OrgMembership{
		OrgID:    defaultOrg.ID,
		UserID:   u.ID,
		Role:     "owner",
		JoinedAt: time.Now(),
	}

	if err := tx.Create(membership).Error; err != nil {
		tx.Rollback()
		return nil, err
	}

	tx.Commit()

	// 生成 Token
	accessToken, err := jwt.GenerateToken(u.ID, u.Email, "user", s.jwtConfig)
	if err != nil {
		return nil, err
	}

	refreshToken, err := jwt.GenerateRefreshToken(u.ID, u.Email, "user", s.jwtConfig)
	if err != nil {
		return nil, err
	}

	return &RegisterResult{
		User:         u,
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		DefaultOrg:   defaultOrg,
	}, nil
}