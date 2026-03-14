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
    let type: OrganizationType
    var memberCount: Int?
    // 注意：不定义 CodingKeys，让 convertFromSnakeCase 自动处理
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