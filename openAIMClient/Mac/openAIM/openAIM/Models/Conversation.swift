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
    let isPublic: Bool?
    let createdBy: String?
    let createdAt: Date
    let updatedAt: Date?
    var participants: [ConversationParticipant]?
    var lastMessage: Message?
    var unreadCount: Int?
    var existing: Bool?  // 标识是否是已存在的会话（后端返回）
    var isDissolved: Bool?  // 标识群聊是否已解散（本地标记）
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
    let role: ParticipantRole?
    let isMuted: Bool?
    let mutedUntil: Date?
}

/// 参与者角色
enum ParticipantRole: String, Codable {
    case owner = "owner"
    case admin = "admin"
    case member = "member"
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
    let isPublic: Bool?
    let participantIds: [ParticipantIdItem]

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case orgId = "orgId"
        case isPublic = "isPublic"
        case participantIds
    }
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

// MARK: - 群聊搜索结果
struct GroupSearchResult: Codable, Identifiable {
    let id: String
    let name: String?
    let participantCount: Int?
    let createdBy: String?
    let creatorName: String?
    let createdAt: Date?
}

// MARK: - 群聊加入请求
struct GroupJoinRequest: Codable, Identifiable {
    let id: String
    let conversationId: String?
    let userId: String?
    let status: GroupJoinRequestStatus?
    let message: String?
    let createdAt: Date?
    var user: User?
}

enum GroupJoinRequestStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
}

// MARK: - 邀请
struct GroupInvitation: Codable, Identifiable {
    let id: String
    let conversationId: String?
    let conversationName: String?
    let inviterId: String?
    let inviteeId: String?
    let status: InvitationStatus?
    let createdAt: Date?
    var inviter: User?
    var invitee: User?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case conversationName = "conversation_name"
        case inviterId = "inviter_id"
        case inviteeId = "invitee_id"
        case status
        case createdAt = "created_at"
        case inviter
        case invitee
    }
}

enum InvitationStatus: String, Codable {
    case pending = "pending"
    case pendingApproval = "pending_approval"
    case approved = "approved"
    case rejected = "rejected"
}