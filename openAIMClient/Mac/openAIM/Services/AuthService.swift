//
//  AuthService.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation

/// 认证服务
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

        // 保存认证信息
        apiClient.setAccessToken(response.data.token.accessToken)
        KeychainHelper.shared.set(response.data.token.refreshToken, forKey: Constants.StorageKeys.refreshToken)

        // 保存用户信息
        currentUser = response.data.user
        saveUser(response.data.user)

        return response.data.user
    }

    /// 用户注册
    func register(email: String, password: String, name: String) async throws -> User {
        let request = RegisterRequest(email: email, password: password, name: name)
        let response: APIResponse<AuthData> = try await apiClient.post(Constants.Auth.register, body: request)

        // 保存认证信息
        apiClient.setAccessToken(response.data.token.accessToken)
        KeychainHelper.shared.set(response.data.token.refreshToken, forKey: Constants.StorageKeys.refreshToken)

        // 保存用户信息
        currentUser = response.data.user
        saveUser(response.data.user)

        return response.data.user
    }

    /// 用户登出
    func logout() async throws {
        let _: APIResponse<Empty> = try await apiClient.post(Constants.Auth.logout, body: Empty())

        // 清除本地数据
        clearAuthData()
    }

    /// 刷新 Token
    func refreshToken() async throws -> Bool {
        guard let refreshToken = KeychainHelper.shared.get(forKey: Constants.StorageKeys.refreshToken) else {
            return false
        }

        do {
            let response: APIResponse<AuthData> = try await apiClient.post(Constants.Auth.refresh, body: ["refresh_token": refreshToken])

            apiClient.setAccessToken(response.data.token.accessToken)
            KeychainHelper.shared.set(response.data.token.refreshToken, forKey: Constants.StorageKeys.refreshToken)

            currentUser = response.data.user
            saveUser(response.data.user)

            return true
        } catch {
            clearAuthData()
            return false
        }
    }

    /// 获取当前用户
    func getCurrentUser() async throws -> User {
        let response: APIResponse<User> = try await apiClient.get(Constants.Users.me)
        currentUser = response.data
        saveUser(response.data)
        return response.data
    }

    /// 检查是否已登录
    func isAuthenticated() -> Bool {
        return KeychainHelper.shared.get(forKey: Constants.StorageKeys.accessToken) != nil
    }

    /// 尝试恢复登录状态
    func restoreSession() async -> Bool {
        guard let _ = KeychainHelper.shared.get(forKey: Constants.StorageKeys.accessToken) else {
            return false
        }

        // 尝试获取用户信息
        do {
            _ = try await getCurrentUser()
            return true
        } catch {
            // Token 可能过期，尝试刷新
            if let _ = KeychainHelper.shared.get(forKey: Constants.StorageKeys.refreshToken) {
                do {
                    return try await refreshToken()
                } catch {
                    return false
                }
            }
            return false
        }
    }

    // MARK: - Private Methods

    private func saveUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: Constants.StorageKeys.currentUser)
        }
    }

    private func loadUser() -> User? {
        guard let data = UserDefaults.standard.data(forKey: Constants.StorageKeys.currentUser),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return user
    }

    private func clearAuthData() {
        apiClient.setAccessToken(nil)
        KeychainHelper.shared.delete(forKey: Constants.StorageKeys.refreshToken)
        KeychainHelper.shared.delete(forKey: Constants.StorageKeys.accessToken)
        UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.currentUser)
        currentUser = nil
    }
}

/// 空响应结构
struct Empty: Codable {
    init() {}
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if !container.decodeNil() {
            // 忽略非空内容
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}