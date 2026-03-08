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

/// 认证视图模型
@MainActor
@Observable
class AuthViewModel {
    // MARK: - Properties
    
    var state: AuthState = .idle
    var currentUser: User?
    var errorMessage: String = ""
    
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
        }
    }
    
    /// 登录
    func login(email: String, password: String) async {
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
    }
    
    /// 清除错误
    func clearError() {
        if case .error = state {
            state = .idle
        }
        errorMessage = ""
    }
}