package main

import (
	"log"

	"github.com/your-org/openim/pkg/config"
	"github.com/your-org/openim/pkg/database"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	db, err := database.Init(cfg.Database)
	if err != nil {
		log.Fatalf("Failed to connect database: %v", err)
	}

	if err := database.Migrate(db); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	log.Println("Database migration completed successfully")
}