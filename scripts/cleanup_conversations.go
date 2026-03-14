package main

import (
	"fmt"
	"log"
	"sort"
	"strings"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	dsn := "host=localhost user=postgres password=postgres dbname=openim port=5432 sslmode=disable"

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	// 获取所有私聊会话及其参与者
	type ConvPart struct {
		ConvID         string
		CreatedAt      string
		ParticipantID  string
	}
	var results []ConvPart

	query := `
		SELECT c.id as conv_id, c.created_at, p.participant_id
		FROM conversations c
		JOIN participants p ON c.id = p.conversation_id
		WHERE c.type = 'direct' AND p.participant_type = 'user'
		ORDER BY c.created_at DESC
	`
	db.Raw(query).Scan(&results)

	// 按会话分组
	convMap := make(map[string][]string)
	convCreatedAt := make(map[string]string)
	for _, r := range results {
		convMap[r.ConvID] = append(convMap[r.ConvID], r.ParticipantID)
		convCreatedAt[r.ConvID] = r.CreatedAt
	}

	// 找出重复的会话
	type ConvInfo struct {
		ID        string
		CreatedAt string
		Parts     string
	}
	participantsToConvs := make(map[string][]ConvInfo)
	for id, parts := range convMap {
		sort.Strings(parts)
		key := strings.Join(parts, "|")
		participantsToConvs[key] = append(participantsToConvs[key], ConvInfo{
			ID:        id,
			CreatedAt: convCreatedAt[id],
			Parts:     key,
		})
	}

	// 找出需要删除的会话
	var toDelete []string
	fmt.Println("Analyzing conversations...")
	for key, convs := range participantsToConvs {
		if len(convs) > 1 {
			fmt.Printf("\nFound %d duplicate conversations for participants: %s\n", len(convs), key)
			// 按创建时间排序，保留最早的
			sort.Slice(convs, func(i, j int) bool {
				return convs[i].CreatedAt < convs[j].CreatedAt
			})
			// 保留第一个，删除其他的
			fmt.Printf("  Keeping: %s (created at %s)\n", convs[0].ID, convs[0].CreatedAt)
			for i := 1; i < len(convs); i++ {
				fmt.Printf("  Will delete: %s (created at %s)\n", convs[i].ID, convs[i].CreatedAt)
				toDelete = append(toDelete, convs[i].ID)
			}
		}
	}

	if len(toDelete) == 0 {
		fmt.Println("\nNo duplicate conversations found!")
		return
	}

	fmt.Printf("\nTotal to delete: %d conversations\n", len(toDelete))

	// 删除重复的会话
	for _, id := range toDelete {
		db.Exec("DELETE FROM participants WHERE conversation_id = ?", id)
		db.Exec("DELETE FROM messages WHERE conversation_id = ?", id)
		db.Exec("DELETE FROM conversations WHERE id = ?", id)
		fmt.Printf("Deleted: %s\n", id)
	}

	fmt.Println("\nDone!")
}