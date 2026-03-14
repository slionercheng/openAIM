//
//  AuthViewModel.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation
import SwiftUI

/// 认证状态
enum AuthState: Equatable {
    case idle
    case loading
    case authenticated
    case error(String)
}

/// 认证视图模型 - 支持 Multi-Instance
@MainActor
@Observable
class AuthViewModel {
    // MARK: - Properties

    var state: AuthState = .idle
    var currentUser: User?
    var errorMessage: String = ""
    var shouldShowAccountSelection = false

    private let authService = AuthService.shared

    // MARK: - Computed Properties

    var isAuthenticated: Bool {
        if case .authenticated = state {
            return true
        }
        return false
    }

    var isLoading: Bool {
        if case .loading = state {
            return true
        }
        return false
    }

    // MARK: - Methods

    /// 检查登录状态
    func checkAuthState() async {
        state = .loading

        let isAuth = await authService.restoreSession()

        if isAuth {
            currentUser = await authService.currentUser
            state = .authenticated
        } else {
            state = .idle
            // 如果有保存的账号，显示选择界面
            if !AccountManager.shared.getSavedAccounts().isEmpty {
                shouldShowAccountSelection = true
            }
        }
    }

    /// 登录
    func login(email: String, password: String, rememberMe: Bool = true) async {
        guard !email.isEmpty, !password.isEmpty else {
            state = .error("请输入邮箱和密码")
            return
        }

        state = .loading
        errorMessage = ""

        do {
            let user = try await authService.login(email: email, password: password)
            currentUser = user
            state = .authenticated

            // 更新 Logger 用户信息
            Logger.shared.updateUser(userId: user.id, email: user.email)

            // rememberMe 的账号信息已经在 AuthService.login 中通过 SessionManager 保存到 AccountManager
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    /// 注册
    func register(email: String, password: String, name: String) async {
        guard !email.isEmpty, !password.isEmpty, !name.isEmpty else {
            state = .error("请填写所有字段")
            return
        }

        guard password.count >= 6 else {
            state = .error("密码至少需要6个字符")
            return
        }

        state = .loading
        errorMessage = ""

        do {
            let user = try await authService.register(email: email, password: password, name: name)
            currentUser = user
            state = .authenticated

            // 更新 Logger 用户信息
            Logger.shared.updateUser(userId: user.id, email: user.email)
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    /// 登出
    func logout() async {
        state = .loading

        await authService.logout()
        currentUser = nil
        state = .idle

        // 清除 Logger 用户信息
        Logger.shared.clearUser()

        // 如果有保存的账号，显示选择界面
        if !AccountManager.shared.getSavedAccounts().isEmpty {
            shouldShowAccountSelection = true
        }
    }

    /// 清除认证状态（被踢下线时使用，不调用登出 API）
    func clearAuthState() {
        // 清除 SessionManager 中的会话
        SessionManager.shared.clearSession()

        currentUser = nil
        state = .idle

        // 清除 Logger 用户信息
        Logger.shared.clearUser()

        // 如果有保存的账号，显示选择界面
        if !AccountManager.shared.getSavedAccounts().isEmpty {
            shouldShowAccountSelection = true
        }
    }

    /// 清除错误
    func clearError() {
        if case .error = state {
            state = .idle
        }
        errorMessage = ""
    }
}