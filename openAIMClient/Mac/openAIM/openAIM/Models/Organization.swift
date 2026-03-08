//
//  Organization.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation

/// 组织模型
struct Organization: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let avatar: String?
    let type: OrganizationType
    let ownerId: String
    var memberCount: Int?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case avatar
        case type
        case ownerId = "owner_id"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// 组织类型
enum OrganizationType: String, Codable {
    case personal = "personal"
    case team = "team"
    case enterprise = "enterprise"
}

/// 组织成员
struct OrgMembership: Codable, Identifiable, Hashable {
    let id: String
    let organizationId: String
    let userId: String
    let role: MemberRole
    var userName: String?
    var userEmail: String?
    let joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case organizationId = "organization_id"
        case userId = "user_id"
        case role
        case userName = "user_name"
        case userEmail = "user_email"
        case joinedAt = "joined_at"
    }
}

/// 成员角色
enum MemberRole: String, Codable {
    case owner = "owner"
    case admin = "admin"
    case member = "member"
}

/// 创建组织请求
struct CreateOrganizationRequest: Codable {
    let name: String
    let description: String?
    let type: OrganizationType
}

/// 邀请成员请求
struct InviteMemberRequest: Codable {
    let email: String
    let role: MemberRole
}