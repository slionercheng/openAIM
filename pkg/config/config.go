package config

import (
	"time"

	"github.com/your-org/openim/pkg/database"
	"github.com/your-org/openim/pkg/jwt"
	"github.com/your-org/openim/pkg/logger"
	"github.com/your-org/openim/pkg/redis"
	"github.com/spf13/viper"
)

type Config struct {
	App      AppConfig
	Database database.DatabaseConfig
	Redis    redis.RedisConfig
	JWT      jwt.JWTConfig
	Log      logger.LogConfig
}

type AppConfig struct {
	Env  string
	Port string
}

// Legacy types for viper unmarshaling - will be converted to package types
type dbConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	DBName   string
	SSLMode  string
}

type rdConfig struct {
	Addr     string
	Password string
	DB       int
}

type jwtConfig struct {
	Secret        string
	Expire        time.Duration
	RefreshExpire time.Duration
}

type logConfig struct {
	Level string
}

func Load() (*Config, error) {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath("./configs")
	viper.AddConfigPath(".")

	viper.AutomaticEnv()

	if err := viper.ReadInConfig(); err != nil {
		return nil, err
	}

	// Use intermediate struct for unmarshaling
	type rawConfig struct {
		App      AppConfig
		Database dbConfig
		Redis    rdConfig
		JWT      jwtConfig
		Log      logConfig
	}

	var raw rawConfig
	if err := viper.Unmarshal(&raw); err != nil {
		return nil, err
	}

	// Convert to final config with proper types
	cfg := &Config{
		App: raw.App,
		Database: database.DatabaseConfig{
			Host:     raw.Database.Host,
			Port:     raw.Database.Port,
			User:     raw.Database.User,
			Password: raw.Database.Password,
			DBName:   raw.Database.DBName,
			SSLMode:  raw.Database.SSLMode,
		},
		Redis: redis.RedisConfig{
			Addr:     raw.Redis.Addr,
			Password: raw.Redis.Password,
			DB:       raw.Redis.DB,
		},
		JWT: jwt.JWTConfig{
			Secret:        raw.JWT.Secret,
			Expire:        raw.JWT.Expire,
			RefreshExpire: raw.JWT.RefreshExpire,
		},
		Log: logger.LogConfig{
			Level: raw.Log.Level,
		},
	}

	return cfg, nil
}