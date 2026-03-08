//
//  Friendship.swift
//  openAIM
//
//  Created by Claude on 2026/3/8.
//

import Foundation

/// 好友关系状态
enum FriendshipStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
    case blocked = "blocked"
}

/// 好友关系状态（从当前用户视角）
enum FriendshipStatusView: String, Codable {
    case none = "none"
    case pendingSent = "pending_sent"
    case pendingReceived = "pending_received"
    case accepted = "accepted"
    case blocked = "blocked"
    case blockedByMe = "blocked_by_me"
}

/// 好友关系
struct Friendship: Codable, Identifiable, Hashable {
    let id: String
    let requesterId: String?
    let addresseeId: String?
    let status: FriendshipStatus
    let createdAt: Date
    let updatedAt: Date?

    // 关联用户信息
    var user: User?
    var requester: User?

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case user
        case requester
    }
}

/// 搜索用户结果
struct SearchUser: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let name: String?
    let avatar: String?
    let status: String?
    var friendshipStatus: FriendshipStatusView?

    enum CodingKeys: String, CodingKey {
        case id, email, name, avatar, status
        case friendshipStatus = "friendship_status"
    }
}

/// 搜索用户响应
struct SearchUsersResponse: Codable {
    let total: Int
    let page: Int
    let pageSize: Int
    let items: [SearchUser]

    enum CodingKeys: String, CodingKey {
        case total, page
        case pageSize = "page_size"
        case items
    }
}

/// 好友列表响应
struct FriendsListResponse: Codable {
    let total: Int
    let page: Int
    let pageSize: Int
    let items: [Friendship]

    enum CodingKeys: String, CodingKey {
        case total, page
        case pageSize = "page_size"
        case items
    }
}

/// 发送好友请求
struct SendFriendRequest: Codable {
    let userId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

/// 好友请求数量响应
struct FriendRequestsCountResponse: Codable {
    let count: Int
}