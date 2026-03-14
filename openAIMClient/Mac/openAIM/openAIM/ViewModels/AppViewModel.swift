//
//  AppViewModel.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import SwiftUI

/// 应用视图模型 - 支持 Multi-Instance
/// 重要：每个实例有独立的 SessionManager 和 WorkspaceManager
@MainActor
@Observable
class AppViewModel {
    var authViewModel = AuthViewModel()
    var conversationViewModel = ConversationViewModel()
    var agentViewModel = AgentViewModel()
    var organizationViewModel = OrganizationViewModel()
    var friendshipViewModel = FriendshipViewModel()

    var currentView: AppView = .login {
        didSet {
            // 当切换离开聊天视图时，清除选中的会话
            // 这样可以确保不在聊天界面时，新消息会增加未读计数
            if currentView != .main {
                conversationViewModel.selectedConversation = nil
            }
        }
    }
    var showAccountSelection = false
    var showKickedAlert = false  // 被踢下线提示
    var showAlreadyOnlineAlert = false  // 已有在线设备提示

    // 新消息通知
    var showNewMessageAlert = false
    var newMessageContent = ""
    var newMessageSender = ""
    var newMessageConversationId = ""

    // 预填的登录邮箱（从账号选择界面传递）
    var prefilledEmail: String = ""

    init() {
        Task {
            await checkAuthState()
        }
    }

    func checkAuthState() async {
        // 检查是否有已保存的账号
        let savedAccounts = AccountManager.shared.getSavedAccounts()

        // 如果有保存的账号，尝试恢复登录状态
        await authViewModel.checkAuthState()

        if authViewModel.isAuthenticated {
            // 更新 Logger 用户信息
            if let user = authViewModel.currentUser {
                Logger.shared.updateUser(userId: user.id, email: user.email)
            }

            currentView = .main
            // 加载初始数据（从工作区和服务器）
            await loadInitialData()
        } else if !savedAccounts.isEmpty {
            // 有保存的账号但当前未登录，显示登录页并弹出账号选择
            currentView = .login
            showAccountSelection = true
        } else {
            currentView = .login
        }
    }

    func loadInitialData() async {
        // 清除旧数据（确保新用户开始时是干净的状态）
        conversationViewModel.clearData()
        agentViewModel.clearData()
        organizationViewModel.clearData()
        friendshipViewModel.clearData()

        // 连接 WebSocket（使用 SessionManager 的 token）
        setupWebSocket()

        // 设置新消息通知回调
        conversationViewModel.onNewMessage = { [weak self] message, conversationName in
            self?.handleNewMessageNotification(message: message, conversationName: conversationName)
        }

        // 先从工作区加载数据（立即显示）
        let localConversations = WorkspaceManager.shared.loadConversations()
        if !localConversations.isEmpty {
            conversationViewModel.conversations = localConversations
            logInfo("AppViewModel", "Loaded \(localConversations.count) conversations from workspace")
        }

        // 从服务器加载数据（后台刷新）
        async let conversations = conversationViewModel.loadConversations()
        async let agents = agentViewModel.loadAgents()
        async let organizations = organizationViewModel.loadOrganizations()
        async let friends = friendshipViewModel.refreshAll()

        _ = await conversations
        _ = await agents
        _ = await organizations
        _ = await friends

        // 保存到工作区
        WorkspaceManager.shared.saveConversations(conversationViewModel.conversations)
    }

    /// 处理新消息通知
    private func handleNewMessageNotification(message: Message, conversationName: String) {
        logInfo("AppViewModel", "New message notification from \(conversationName): \(message.content.prefix(50))")
        newMessageContent = message.content
        newMessageSender = conversationName
        newMessageConversationId = message.conversationId
        showNewMessageAlert = true
    }

    /// 打开新消息所在的会话
    func openNewMessageConversation() {
        showNewMessageAlert = false
        // 切换到主界面并选择会话
        currentView = .main
        if let conversation = conversationViewModel.conversations.first(where: { $0.id == newMessageConversationId }) {
            Task {
                await conversationViewModel.selectConversation(conversation)
            }
        }
    }

    /// 关闭新消息通知
    func dismissNewMessageAlert() {
        showNewMessageAlert = false
    }

    private func setupWebSocket() {
        // 使用 SessionManager 的 token（实例独享）
        guard let token = SessionManager.shared.accessToken else {
            logWarn("AppViewModel", "No token available for WebSocket")
            return
        }

        // 设置 WebSocket 消息回调
        WebSocketService.shared.onMessageReceived = { [weak self] message in
            self?.conversationViewModel.handleNewMessage(message)
        }

        // 设置被踢下线回调
        WebSocketService.shared.onKicked = { [weak self] in
            self?.handleKicked()
        }

        // 设置已有在线设备回调
        WebSocketService.shared.onAlreadyOnline = { [weak self] in
            self?.handleAlreadyOnline()
        }

        // 连接 WebSocket
        WebSocketService.shared.connect(token: token)
        logInfo("AppViewModel", "WebSocket connected with session token")
    }

    /// 处理被踢下线
    private func handleKicked() {
        logWarn("AppViewModel", "User kicked - another login detected")
        showKickedAlert = true
        currentView = .login
        // 清除认证状态但不调用 logout（避免清除保存的账号）
        authViewModel.clearAuthState()
        Logger.shared.clearUser()  // 清除 Logger 用户信息
        // 断开 WebSocket
        WebSocketService.shared.disconnect()

        // 如果有保存的账号，显示选择界面
        if !AccountManager.shared.getSavedAccounts().isEmpty {
            showAccountSelection = true
        }
    }

    /// 处理已有在线设备
    private func handleAlreadyOnline() {
        logInfo("AppViewModel", "Already online detected - showing confirmation")
        showAlreadyOnlineAlert = true
    }

    /// 确认强制登录（顶替旧设备）
    func confirmForceLogin() {
        logInfo("AppViewModel", "User confirmed force login")
        showAlreadyOnlineAlert = false
        WebSocketService.shared.confirmForceLogin()
        // 连接成功后会收到 login_success，此时可以加载数据
        Task {
            await loadInitialDataAfterForceLogin()
        }
    }

    /// 取消强制登录
    func cancelForceLogin() {
        logInfo("AppViewModel", "User cancelled force login")
        showAlreadyOnlineAlert = false
        WebSocketService.shared.cancelLogin()
        // 清除认证状态
        authViewModel.clearAuthState()
        Logger.shared.clearUser()  // 清除 Logger 用户信息
        currentView = .login

        // 如果有保存的账号，显示选择界面
        if !AccountManager.shared.getSavedAccounts().isEmpty {
            showAccountSelection = true
        }
    }

    /// 强制登录成功后加载数据
    private func loadInitialDataAfterForceLogin() async {
        async let conversations = conversationViewModel.loadConversations()
        async let agents = agentViewModel.loadAgents()
        async let organizations = organizationViewModel.loadOrganizations()
        async let friends = friendshipViewModel.refreshAll()

        _ = await conversations
        _ = await agents
        _ = await organizations
        _ = await friends
    }

    func logout() async {
        // 断开 WebSocket
        WebSocketService.shared.disconnect()
        Logger.shared.clearUser()  // 清除 Logger 用户信息

        await authViewModel.logout()
        currentView = .login

        // 如果有保存的账号，显示选择界面
        if !AccountManager.shared.getSavedAccounts().isEmpty {
            showAccountSelection = true
        }
    }
}

/// 应用视图类型
enum AppView {
    case login
    case register
    case main
    case contacts
    case agents
    case organizations
    case settings
}