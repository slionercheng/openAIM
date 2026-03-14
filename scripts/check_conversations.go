package main

import (
	"fmt"
	"log"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	dsn := "host=localhost user=postgres password=postgres dbname=openim port=5432 sslmode=disable"

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	// 查询所有会话及其参与者
	type ConvInfo struct {
		ID           string
		Type         string
		CreatedAt    string
		ParticipantCount int
		Participants string
	}
	var results []ConvInfo

	query := `
		SELECT c.id, c.type, c.created_at,
		       COUNT(p.participant_id) as participant_count,
		       string_agg(p.participant_id, ', ') as participants
		FROM conversations c
		LEFT JOIN participants p ON c.id = p.conversation_id
		GROUP BY c.id, c.type, c.created_at
		ORDER BY c.created_at DESC
	`
	db.Raw(query).Scan(&results)

	fmt.Println("=== All Conversations ===")
	for _, r := range results {
		fmt.Printf("\nID: %s\n", r.ID)
		fmt.Printf("Type: %s\n", r.Type)
		fmt.Printf("Created: %s\n", r.CreatedAt)
		fmt.Printf("Participant Count: %d\n", r.ParticipantCount)
		fmt.Printf("Participants: %s\n", r.Participants)

		// 标记可能有问题的会话
		if r.ParticipantCount == 0 {
			fmt.Println("⚠️  WARNING: No participants!")
		} else if r.ParticipantCount == 1 && r.Type == "direct" {
			fmt.Println("⚠️  WARNING: Direct chat with only 1 participant!")
		}
	}

	// 删除有问题的会话
	fmt.Println("\n=== Cleaning up invalid conversations ===")

	// 删除没有参与者的会话
	var noPartConv []string
	db.Raw(`
		SELECT c.id FROM conversations c
		LEFT JOIN participants p ON c.id = p.conversation_id
		WHERE p.participant_id IS NULL
	`).Scan(&noPartConv)

	for _, id := range noPartConv {
		db.Exec("DELETE FROM conversations WHERE id = ?", id)
		fmt.Printf("Deleted conversation with no participants: %s\n", id)
	}

	// 删除只有一个参与者的私聊
	var singlePartConv []string
	db.Raw(`
		SELECT c.id FROM conversations c
		WHERE c.type = 'direct'
		AND (SELECT COUNT(*) FROM participants WHERE conversation_id = c.id) = 1
	`).Scan(&singlePartConv)

	fmt.Printf("\nFound %d direct chats with single participant\n", len(singlePartConv))
	for _, id := range singlePartConv {
		db.Exec("DELETE FROM participants WHERE conversation_id = ?", id)
		db.Exec("DELETE FROM messages WHERE conversation_id = ?", id)
		db.Exec("DELETE FROM conversations WHERE id = ?", id)
		fmt.Printf("Deleted direct chat with single participant: %s\n", id)
	}

	fmt.Println("\nDone!")
}