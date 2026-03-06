.PHONY: all build run test clean migrate-up migrate-down docker-up docker-down

# 变量
APP_NAME := openim
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME := $(shell date -u '+%Y-%m-%d_%H:%M:%S')
LDFLAGS := -ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)"

# Go 参数
GOCMD := go
GOBUILD := $(GOCMD) build
GOTEST := $(GOCMD) test
GOGET := $(GOCMD) get
GOMOD := $(GOCMD) mod

# 目录
BIN_DIR := bin
CMD_DIR := cmd/server

# 默认目标
all: build

# 编译
build:
	@echo "Building $(APP_NAME)..."
	@mkdir -p $(BIN_DIR)
	$(GOBUILD) $(LDFLAGS) -o $(BIN_DIR)/$(APP_NAME) ./$(CMD_DIR)

# 运行
run:
	@echo "Running $(APP_NAME)..."
	$(GOCMD) run ./$(CMD_DIR)

# 测试
test:
	@echo "Running tests..."
	$(GOTEST) -v ./...

# 清理
clean:
	@echo "Cleaning..."
	@rm -rf $(BIN_DIR)

# 数据库迁移
migrate-up:
	@echo "Running database migrations..."
	$(GOCMD) run ./cmd/migrate

migrate-down:
	@echo "Rolling back database migrations..."
	@echo "Not implemented yet"

# Docker
docker-up:
	@echo "Starting Docker containers..."
	docker-compose up -d

docker-down:
	@echo "Stopping Docker containers..."
	docker-compose down

docker-dev:
	@echo "Starting development Docker containers..."
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

docker-logs:
	docker-compose logs -f

# 依赖
deps:
	@echo "Downloading dependencies..."
	$(GOMOD) download
	$(GOMOD) tidy

# 代码检查
lint:
	@echo "Running linter..."
	@which golangci-lint > /dev/null || go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	golangci-lint run ./...

# 代码格式化
fmt:
	@echo "Formatting code..."
	$(GOCMD) fmt ./...

# 帮助
help:
	@echo "Available targets:"
	@echo "  make build        - 编译项目"
	@echo "  make run          - 运行项目"
	@echo "  make test         - 运行测试"
	@echo "  make clean        - 清理编译文件"
	@echo "  make migrate-up   - 运行数据库迁移"
	@echo "  make docker-up    - 启动 Docker 容器"
	@echo "  make docker-down  - 停止 Docker 容器"
	@echo "  make docker-dev   - 启动开发环境 Docker 容器"
	@echo "  make deps         - 下载依赖"
	@echo "  make lint         - 代码检查"
	@echo "  make fmt          - 代码格式化"