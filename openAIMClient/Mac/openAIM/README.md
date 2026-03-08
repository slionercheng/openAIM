# OpenAIM Mac Client

一个基于 SwiftUI 的 macOS 即时通讯客户端，支持 AI Agent 集成。

## 功能特性

- **用户认证**: 登录、注册、Token 刷新
- **即时通讯**: 单聊、群聊、实时消息
- **AI Agent**: 创建和管理 AI 助手，支持自定义技能
- **组织管理**: 团队协作、成员权限管理
- **WebSocket**: 实时消息推送

## 技术栈

- **语言**: Swift 5.9+
- **框架**: SwiftUI
- **架构**: MVVM
- **最低支持**: macOS 14.0
- **网络**: URLSession + async/await
- **实时通信**: WebSocket

## 项目结构

```
openAIM/
├── openAIMApp.swift          # 应用入口
├── ContentView.swift         # 根视图
├── Models/                   # 数据模型
│   ├── User.swift
│   ├── Agent.swift
│   ├── Organization.swift
│   ├── Conversation.swift
│   └── Message.swift
├── ViewModels/               # 视图模型
│   ├── AuthViewModel.swift
│   ├── ConversationViewModel.swift
│   ├── AgentViewModel.swift
│   └── OrganizationViewModel.swift
├── Views/                    # 视图组件
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   ├── Chat/
│   │   ├── MainView.swift
│   │   ├── ConversationListView.swift
│   │   └── ChatView.swift
│   ├── Agent/
│   │   ├── AgentListView.swift
│   │   └── CreateAgentView.swift
│   └── Organization/
│       └── OrganizationView.swift
├── Services/                 # API 服务
│   ├── APIClient.swift
│   ├── AuthService.swift
│   ├── ConversationService.swift
│   ├── AgentService.swift
│   ├── OrganizationService.swift
│   └── WebSocketService.swift
└── Utils/                    # 工具类
    ├── Constants.swift
    ├── Extensions.swift
    └── KeychainHelper.swift
```

## API 接口

后端服务运行在 `http://localhost:8080`

### 认证
- `POST /api/v1/auth/register` - 注册
- `POST /api/v1/auth/login` - 登录
- `POST /api/v1/auth/logout` - 登出
- `POST /api/v1/auth/refresh` - 刷新 Token

### 用户
- `GET /api/v1/users/me` - 当前用户信息
- `PUT /api/v1/users/me` - 更新用户

### 会话
- `GET /api/v1/conversations` - 会话列表
- `POST /api/v1/conversations` - 创建会话
- `GET /api/v1/conversations/:id/messages` - 消息历史
- `POST /api/v1/conversations/:id/messages` - 发送消息

### Agent
- `GET /api/v1/agents` - Agent 列表
- `POST /api/v1/agents` - 创建 Agent
- `PUT /api/v1/agents/:id` - 更新 Agent
- `DELETE /api/v1/agents/:id` - 删除 Agent

### 组织
- `GET /api/v1/organizations` - 组织列表
- `POST /api/v1/organizations` - 创建组织
- `GET /api/v1/organizations/:id/members` - 成员列表

### WebSocket
- `GET /ws` - WebSocket 连接

## 配色方案

| 用途 | 颜色 |
|------|------|
| 主蓝色 | `#3B82F6` |
| 背景灰 | `#F8FAFC` / `#F1F5F9` |
| 卡片白 | `#FFFFFF` |
| 边框灰 | `#E2E8F0` |
| 标题文字 | `#1E293B` |
| 次级文字 | `#64748B` |
| 辅助文字 | `#94A3B8` |

## 开发指南

### 环境要求
- Xcode 15.0+
- macOS 14.0+
- Swift 5.9+

### 运行项目
1. 打开 `openAIM.xcodeproj`
2. 选择目标设备
3. 按 `Cmd + R` 运行

### 设计稿
设计稿位于 `docs/openAIM-UI-design.pen`，可使用 Pencil VSCode 扩展打开。

## License

MIT