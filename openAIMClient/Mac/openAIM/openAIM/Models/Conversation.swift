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
    let createdBy: String
    let createdAt: Date
    let updatedAt: Date
    var lastMessage: Message?
    var unreadCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case organizationId = "organization_id"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastMessage = "last_message"
        case unreadCount = "unread_count"
    }
}

/// 会话类型
enum ConversationType: String, Codable {
    case direct = "direct"
    case group = "group"
}

/// 会话参与者
struct Participant: Codable, Identifiable, Hashable {
    let id: String
    let conversationId: String
    let participantType: ParticipantType
    let participantId: String
    let joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case participantType = "participant_type"
        case participantId = "participant_id"
        case joinedAt = "joined_at"
    }
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
    let organizationId: String?
    let participantIds: [String]
}

/// 添加参与者请求
struct AddParticipantRequest: Codable {
    let participantType: ParticipantType
    let participantId: String
}