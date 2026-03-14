//
//  User.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation

/// 用户模型
struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let name: String?
    let avatar: String?
    var status: UserStatus?
    var online: Bool?
    var createdAt: Date?
    var updatedAt: Date?
}

/// 用户状态
enum UserStatus: String, Codable {
    case active = "active"
    case inactive = "inactive"
    case offline = "offline"
}

/// 用户登录请求
struct LoginRequest: Codable {
    let email: String
    let password: String
}

/// 用户注册请求
struct RegisterRequest: Codable {
    let email: String
    let password: String
    let name: String
}

/// Token 对象 - 属性名使用 camelCase，decoder 会自动从 snake_case 转换
struct TokenData: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int?
}

/// 认证响应数据
struct AuthData: Codable {
    let token: TokenData
    let user: User
    let defaultOrg: DefaultOrg?
}

/// 默认组织
struct DefaultOrg: Codable {
    let id: String
    let name: String
    let type: String
}

/// 用户更新请求
struct UserUpdateRequest: Codable {
    let name: String?
    let avatar: String?
}