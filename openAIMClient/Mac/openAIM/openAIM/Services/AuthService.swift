//
//  AuthService.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation

/// 认证服务 - 支持 Multi-Instance
/// 重要：会话状态存储在 SessionManager 中，每个实例独立
actor AuthService {
    static let shared = AuthService()

    private let apiClient = APIClient.shared
    private(set) var currentUser: User?

    private init() {}

    // MARK: - Public Methods

    /// 用户登录
    func login(email: String, password: String) async throws -> User {
        let request = LoginRequest(email: email, password: password)
        let response: APIResponse<AuthData> = try await apiClient.post(Constants.Auth.login, body: request)

        let user = response.data.user
        let token = response.data.token

        // 在 SessionManager 中创建会话（内存中，实例独享）
        await MainActor.run {
            SessionManager.shared.createSession(
                userId: user.id,
                email: user.email,
                name: user.name,
                avatar: user.avatar,
                accessToken: token.accessToken,
                refreshToken: token.refreshToken
            )
        }

        // 保存用户信息
        currentUser = user

        await MainActor.run {
            logInfo("AuthService", "User logged in: \(email)")
        }

        return user
    }

    /// 用户注册
    func register(email: String, password: String, name: String) async throws -> User {
        let request = RegisterRequest(email: email, password: password, name: name)
        let response: APIResponse<AuthData> = try await apiClient.post(Constants.Auth.register, body: request)

        let user = response.data.user
        let token = response.data.token

        // 在 SessionManager 中创建会话
        await MainActor.run {
            SessionManager.shared.createSession(
                userId: user.id,
                email: user.email,
                name: user.name,
                avatar: user.avatar,
                accessToken: token.accessToken,
                refreshToken: token.refreshToken
            )
        }

        currentUser = user

        await MainActor.run {
            logInfo("AuthService", "User registered: \(email)")
        }

        return user
    }

    /// 用户登出
    func logout() async {
        // 先尝试通知后端
        do {
            let _: APIResponse<Empty> = try await apiClient.post(Constants.Auth.logout, body: EmptyData())
        } catch {
            // 忽略后端错误
        }

        // 清除会话
        await MainActor.run {
            SessionManager.shared.clearSession()
        }
        currentUser = nil

        await MainActor.run {
            logInfo("AuthService", "User logged out")
        }
    }

    /// 清除本地认证数据（被踢下线时使用）
    func clearLocalAuthData() {
        Task { @MainActor in
            SessionManager.shared.clearSession()
        }
        currentUser = nil
    }

    /// 刷新 Token
    func refreshToken() async throws -> Bool {
        guard let refreshToken = await SessionManager.shared.refreshToken else {
            return false
        }

        do {
            let response: APIResponse<AuthData> = try await apiClient.post(Constants.Auth.refresh, body: ["refresh_token": refreshToken])

            let user = response.data.user
            let token = response.data.token

            // 更新 SessionManager 中的令牌
            await MainActor.run {
                SessionManager.shared.updateTokens(
                    accessToken: token.accessToken,
                    refreshToken: token.refreshToken
                )
            }

            currentUser = user
            return true
        } catch {
            // 刷新失败，清除会话
            await MainActor.run {
                SessionManager.shared.clearSession()
            }
            return false
        }
    }

    /// 获取当前用户
    func getCurrentUser() async throws -> User {
        let response: APIResponse<User> = try await apiClient.get(Constants.Users.me)
        currentUser = response.data
        return response.data
    }

    /// 检查是否已登录（检查 SessionManager）
    func isAuthenticated() async -> Bool {
        return await SessionManager.shared.isAuthenticated
    }

    /// 从已保存的账号恢复会话
    func restoreSession(from account: SavedAccount) async -> Bool {
        // 在 SessionManager 中恢复会话
        let success = await SessionManager.shared.restoreSession(from: account)
        guard success else { return false }

        // 验证 token 是否有效
        do {
            _ = try await getCurrentUser()
            await MainActor.run {
                logInfo("AuthService", "Session restored for: \(account.email)")
            }
            return true
        } catch {
            // Token 过期，尝试刷新
            do {
                _ = try await refreshToken()
                await MainActor.run {
                    logInfo("AuthService", "Session restored with refreshed token for: \(account.email)")
                }
                return true
            } catch {
                await MainActor.run {
                    logWarn("AuthService", "Failed to restore session for: \(account.email)")
                    SessionManager.shared.clearSession()
                }
                return false
            }
        }
    }

    /// 尝试恢复登录状态（自动选择最近账号）
    func restoreSession() async -> Bool {
        // 检查是否有已保存的账号
        let accounts = await AccountManager.shared.getSavedAccounts()
        guard let recentAccount = accounts.first else {
            return false
        }

        return await restoreSession(from: recentAccount)
    }
}

/// 空请求数据
struct EmptyData: Codable {}