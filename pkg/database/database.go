package database

import (
	"fmt"

	"github.com/your-org/openim/internal/domain/agent"
	"github.com/your-org/openim/internal/domain/conversation"
	"github.com/your-org/openim/internal/domain/event"
	"github.com/your-org/openim/internal/domain/friendship"
	"github.com/your-org/openim/internal/domain/message"
	"github.com/your-org/openim/internal/domain/organization"
	"github.com/your-org/openim/internal/domain/user"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type DatabaseConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	DBName   string
	SSLMode  string
}

func Init(cfg DatabaseConfig) (*gorm.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.DBName, cfg.SSLMode,
	)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	return db, nil
}

func Migrate(db *gorm.DB) error {
	return db.AutoMigrate(
		&user.User{},
		&organization.Organization{},
		&organization.OrgMembership{},
		&organization.Invitation{},
		&agent.Agent{},
		&agent.AgentOrgMembership{},
		&agent.JoinRequest{},
		&conversation.Conversation{},
		&conversation.Participant{},
		&conversation.JoinRequest{},
		&conversation.Invitation{},
		&message.Message{},
		&friendship.Friendship{},
		&event.Event{},
	)
}