//
//  SessionManager.swift
//  openAIM
//
//  Created by Claude on 2026/3/14.
//

import Foundation

/// 会话状态
struct SessionState: Codable {
    let userId: String
    let email: String
    let name: String?
    let avatar: String?
    let accessToken: String
    let refreshToken: String
    let loginAt: Date

    var displayName: String {
        name ?? email
    }
}

/// 会话管理器 - 管理当前实例的用户会话
/// 重要：每个应用实例有独立的 SessionManager，支持多实例同时登录不同用户
@MainActor
@Observable
class SessionManager {
    static let shared = SessionManager()

    // MARK: - 会话状态（内存中，实例独享）

    /// 当前会话状态（内存唯一来源）
    private(set) var currentSession: SessionState?

    /// 是否已登录
    var isAuthenticated: Bool {
        currentSession != nil
    }

    /// 当前用户 ID
    var currentUserId: String? {
        currentSession?.userId
    }

    /// 当前用户邮箱
    var currentUserEmail: String? {
        currentSession?.email
    }

    /// 当前访问令牌
    var accessToken: String? {
        currentSession?.accessToken
    }

    /// 当前刷新令牌
    var refreshToken: String? {
        currentSession?.refreshToken
    }

    private init() {}

    // MARK: - 会话管理

    /// 创建新会话（登录成功后调用）
    func createSession(
        userId: String,
        email: String,
        name: String?,
        avatar: String?,
        accessToken: String,
        refreshToken: String
    ) {
        let session = SessionState(
            userId: userId,
            email: email,
            name: name,
            avatar: avatar,
            accessToken: accessToken,
            refreshToken: refreshToken,
            loginAt: Date()
        )
        self.currentSession = session

        // 切换到用户的工作区
        WorkspaceManager.shared.switchToWorkspace(userId: userId, email: email)

        logInfo("SessionManager", "Session created for user: \(email)")

        // 保存到账号管理器（用于账号选择界面）
        AccountManager.shared.saveAccount(
            userId: userId,
            email: email,
            name: name,
            avatar: avatar,
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }

    /// 从已保存的账号恢复会话
    func restoreSession(from account: SavedAccount) -> Bool {
        let session = SessionState(
            userId: account.id,
            email: account.email,
            name: account.name,
            avatar: account.avatar,
            accessToken: account.accessToken,
            refreshToken: account.refreshToken,
            loginAt: account.lastLoginAt
        )
        self.currentSession = session

        // 切换到用户的工作区
        WorkspaceManager.shared.switchToWorkspace(userId: account.id, email: account.email)

        logInfo("SessionManager", "Session restored for user: \(account.email)")
        return true
    }

    /// 更新令牌
    func updateTokens(accessToken: String, refreshToken: String) {
        guard let old = currentSession else { return }
        currentSession = SessionState(
            userId: old.userId,
            email: old.email,
            name: old.name,
            avatar: old.avatar,
            accessToken: accessToken,
            refreshToken: refreshToken,
            loginAt: old.loginAt
        )

        // 同步更新 AccountManager
        AccountManager.shared.updateTokens(
            userId: old.userId,
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }

    /// 清除会话（登出）
    func clearSession() {
        if let email = currentSession?.email {
            logInfo("SessionManager", "Session cleared for user: \(email)")
        }
        currentSession = nil

        // 清除工作区
        WorkspaceManager.shared.clearWorkspace()
    }

    /// 检查是否是当前用户
    func isCurrentUser(_ userId: String) -> Bool {
        currentSession?.userId == userId
    }
}