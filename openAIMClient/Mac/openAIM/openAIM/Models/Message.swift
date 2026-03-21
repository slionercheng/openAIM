//
//  Message.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation

/// 消息模型
struct Message: Codable, Identifiable, Hashable {
    let id: String
    let conversationId: String
    let senderType: SenderType
    let senderId: String
    let content: String
    let contentType: ContentType
    let metadata: [String: String]?
    let createdAt: Date
    // 注意：不定义 CodingKeys，让 convertFromSnakeCase 自动处理
}

/// 发送者类型
enum SenderType: String, Codable {
    case user = "user"
    case agent = "agent"
    case system = "system"
}

/// 内容类型
enum ContentType: String, Codable {
    case text = "text"
    case markdown = "markdown"
    case json = "json"
    case system = "system"
    case inviteRequest = "invite_request"
}

/// 邀请请求元数据
struct InviteRequestMetadata: Codable {
    let invitationId: String
    let inviterId: String
    let inviterName: String
    let inviteeId: String
    let inviteeName: String
    let status: String  // pending, approved, rejected
    let approvedBy: String?

    enum CodingKeys: String, CodingKey {
        case invitationId = "invitation_id"
        case inviterId = "inviter_id"
        case inviterName = "inviter_name"
        case inviteeId = "invitee_id"
        case inviteeName = "invitee_name"
        case status
        case approvedBy = "approved_by"
    }
}

/// 发送消息请求
struct SendMessageRequest: Codable {
    let content: String
    let contentType: ContentType
    let metadata: [String: String]?
}

/// 消息列表响应
struct MessageListResponse: Codable {
    let list: [Message]
    let total: Int
    let page: Int
    let pageSize: Int
    // 注意：不定义 CodingKeys，让 convertFromSnakeCase 自动处理
}