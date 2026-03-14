//
//  Conversation.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation

/// 会话模型
struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let type: ConversationType
    let organizationId: String?
    let createdBy: String?
    let createdAt: Date
    let updatedAt: Date?
    var participants: [ConversationParticipant]?
    var lastMessage: Message?
    var unreadCount: Int?
    // 注意：不定义 CodingKeys，让 convertFromSnakeCase 自动处理
}

/// 会话类型
enum ConversationType: String, Codable {
    case direct = "direct"
    case group = "group"
}

/// 会话参与者（API响应格式）
struct ConversationParticipant: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let name: String?
    let avatar: String?
}

/// 会话参与者（数据库格式）
struct Participant: Codable, Identifiable, Hashable {
    let id: String
    let conversationId: String
    let participantType: ParticipantType
    let participantId: String
    let joinedAt: Date
}

/// 参与者类型
enum ParticipantType: String, Codable {
    case user = "user"
    case agent = "agent"
}

/// 创建会话请求
struct CreateConversationRequest: Codable {
    let name: String?
    let type: ConversationType
    let orgId: String?
    let participantIds: [ParticipantIdItem]
}

/// 参与者ID项
struct ParticipantIdItem: Codable {
    let type: String
    let id: String
}

/// 添加参与者请求
struct AddParticipantRequest: Codable {
    let participantType: ParticipantType
    let participantId: String
}