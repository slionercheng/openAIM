package idgen

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"sync"
	"time"
)

// ID类型前缀常量
const (
	TypeUser         = "usr"
	TypeAgent        = "agt"
	TypeOrg          = "org"
	TypeConv         = "conv"
	TypeMessage      = "msg"
	TypeFriendReq    = "freq"
	TypeJoinReq      = "jreq"
	TypeInvitation   = "inv"
	TypeNotification = "ntf"
	TypeEvent        = "evt"
	TypeParticipant  = "part"
	TypeMembership   = "mbr"
)

var (
	instance *Generator
	once     sync.Once
)

// Generator ID生成器
type Generator struct {
	machineID uint16
	sequence  uint64
	lastTime  int64
	mu        sync.Mutex
}

// Init 初始化ID生成器
func Init(machineID uint16) {
	once.Do(func() {
		instance = &Generator{
			machineID: machineID,
		}
	})
}

// GetGenerator 获取ID生成器实例
func GetGenerator() *Generator {
	if instance == nil {
		Init(1) // 默认机器ID为1
	}
	return instance
}

// Generate 生成带类型前缀的ID
// 格式: {type}_{timestamp}_{random}
// 示例: msg_20260308123458_ghi789
func Generate(typePrefix string) string {
	g := GetGenerator()
	return g.generateID(typePrefix)
}

// GenerateSimple 生成简单ID（仅前缀+雪花ID）
// 格式: {type}_{snowflake_id}
// 示例: msg_1234567890123456789
func GenerateSimple(typePrefix string) string {
	g := GetGenerator()
	id := g.nextID()
	return fmt.Sprintf("%s_%d", typePrefix, id)
}

// generateID 生成完整格式的ID
func (g *Generator) generateID(typePrefix string) string {
	now := time.Now().UTC()
	timestamp := now.Format("20060102150405")
	random := randomHex(6)
	return fmt.Sprintf("%s_%s_%s", typePrefix, timestamp, random)
}

// nextID 生成雪花ID
func (g *Generator) nextID() uint64 {
	g.mu.Lock()
	defer g.mu.Unlock()

	now := time.Now().UnixMilli()

	// 如果是同一毫秒
	if now == g.lastTime {
		g.sequence++
	} else {
		g.sequence = 0
		g.lastTime = now
	}

	// 组装ID: 时间戳(41位) + 机器ID(10位) + 序列号(12位)
	id := uint64((now & 0x1FFFFFFFFFF) << 22)
	id |= uint64(g.machineID&0x3FF) << 12
	id |= uint64(g.sequence & 0xFFF)

	return id
}

// randomHex 生成指定长度的随机十六进制字符串
func randomHex(length int) string {
	bytes := make([]byte, length/2+1)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)[:length]
}

// ParseID 解析ID，返回类型前缀和时间
func ParseID(id string) (typePrefix string, timestamp time.Time, err error) {
	// 简单格式: type_snowflake_id
	// 完整格式: type_YYYYMMDDHHMMSS_random

	parts := splitID(id)
	if len(parts) < 2 {
		return "", time.Time{}, fmt.Errorf("invalid id format: %s", id)
	}

	typePrefix = parts[0]

	// 尝试解析时间戳
	if len(parts) >= 3 {
		// 完整格式
		ts, err := time.Parse("20060102150405", parts[1])
		if err == nil {
			return typePrefix, ts, nil
		}
	}

	return typePrefix, time.Time{}, nil
}

// splitID 分割ID
func splitID(id string) []string {
	result := make([]string, 0, 3)
	start := 0
	for i := 0; i < len(id); i++ {
		if id[i] == '_' {
			result = append(result, id[start:i])
			start = i + 1
		}
	}
	if start < len(id) {
		result = append(result, id[start:])
	}
	return result
}

// GetType 从ID中提取类型前缀
func GetType(id string) string {
	parts := splitID(id)
	if len(parts) > 0 {
		return parts[0]
	}
	return ""
}