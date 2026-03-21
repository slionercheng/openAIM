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

    // 群邀请通知
    var showGroupInvitationAlert = false
    var groupInvitationMessage = ""
    var pendingGroupInvitation: GroupInvitation?

    // 群聊解散通知
    var dissolvedConversationIds: Set<String> = []

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

        // 设置 ViewModel 之间的引用
        friendshipViewModel.conversationViewModel = conversationViewModel

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

    /// 处理成员离开事件
    private func handleMemberLeft(conversationId: String, userId: String, userName: String, systemMessage: (id: String, content: String, createdAt: Date)?, newOwnerId: String?, newOwnerName: String?) {
        logInfo("AppViewModel", "Member left: \(userName) from conversation \(conversationId)")

        // 创建系统消息（优先使用服务端提供的）
        let msg: Message
        if let sysMsg = systemMessage {
            msg = Message(
                id: sysMsg.id,
                conversationId: conversationId,
                senderType: .system,
                senderId: "system",
                content: sysMsg.content,
                contentType: .system,
                metadata: nil,
                createdAt: sysMsg.createdAt
            )
        } else {
            var content = "\(userName) 离开了群聊"
            if let newOwner = newOwnerName {
                content = "\(userName) 离开了群聊，\(newOwner) 成为新群主"
            }
            msg = Message(
                id: UUID().uuidString,
                conversationId: conversationId,
                senderType: .system,
                senderId: "system",
                content: content,
                contentType: .system,
                metadata: nil,
                createdAt: Date()
            )
        }

        // 添加系统消息到消息列表
        conversationViewModel.handleNewMessage(msg)

        // 刷新会话列表以更新参与者，并更新 selectedConversation
        Task {
            await conversationViewModel.loadConversations()
            // 如果当前正在查看这个会话，更新 selectedConversation
            if conversationViewModel.selectedConversation?.id == conversationId {
                if let updatedConv = conversationViewModel.conversations.first(where: { $0.id == conversationId }) {
                    conversationViewModel.selectedConversation = updatedConv
                }
            }
        }
    }

    /// 处理新成员加入事件
    private func handleMemberJoined(conversationId: String, userId: String, userName: String, systemMessage: (id: String, content: String, createdAt: Date)?) {
        logInfo("AppViewModel", "Member joined: \(userName) to conversation \(conversationId)")

        // 创建系统消息（优先使用服务端提供的）
        let msg: Message
        if let sysMsg = systemMessage {
            msg = Message(
                id: sysMsg.id,
                conversationId: conversationId,
                senderType: .system,
                senderId: "system",
                content: sysMsg.content,
                contentType: .system,
                metadata: nil,
                createdAt: sysMsg.createdAt
            )
        } else {
            msg = Message(
                id: UUID().uuidString,
                conversationId: conversationId,
                senderType: .system,
                senderId: "system",
                content: "\(userName) 加入了群聊",
                contentType: .system,
                metadata: nil,
                createdAt: Date()
            )
        }

        // 添加系统消息到消息列表
        conversationViewModel.handleNewMessage(msg)

        // 刷新会话列表以更新参与者，并更新 selectedConversation
        Task {
            await conversationViewModel.loadConversations()
            // 如果当前正在查看这个会话，更新 selectedConversation
            if conversationViewModel.selectedConversation?.id == conversationId {
                if let updatedConv = conversationViewModel.conversations.first(where: { $0.id == conversationId }) {
                    conversationViewModel.selectedConversation = updatedConv
                }
            }
        }
    }

    /// 处理收到群邀请（等待管理员审批）
    private func handleGroupInvitation(_ invitation: GroupInvitation) {
        logInfo("AppViewModel", "Received group invitation: \(invitation.id)")
        // 添加到群邀请列表
        friendshipViewModel.handleNewGroupInvitation(invitation)
    }

    /// 处理被管理员邀请直接加入群聊
    private func handleGroupJoined(conversationId: String, conversationName: String) {
        logInfo("AppViewModel", "Joined group: \(conversationName)")
        // 不显示弹窗，直接刷新会话列表，新群聊会出现在列表顶部
        Task {
            await conversationViewModel.loadConversations()
        }
    }

    /// 处理群邀请被批准
    private func handleGroupInvitationApproved(invitationId: String, conversationId: String) {
        logInfo("AppViewModel", "Group invitation approved: \(invitationId)")
        // 不显示弹窗，直接刷新会话列表
        Task {
            await conversationViewModel.loadConversations()
        }
    }

    /// 处理群聊解散
    private func handleGroupDissolved(conversationId: String, conversationName: String) {
        logInfo("AppViewModel", "Group dissolved: \(conversationName)")

        // 标记群聊为已解散
        dissolvedConversationIds.insert(conversationId)

        // 如果当前正在查看这个群聊，清除选中状态
        if conversationViewModel.selectedConversation?.id == conversationId {
            conversationViewModel.selectedConversation = nil
        }

        // 从会话列表中移除该群聊
        conversationViewModel.conversations.removeAll { $0.id == conversationId }
    }

    /// 处理邀请请求状态更新
    private func handleInviteRequestUpdated(conversationId: String, invitationId: String, status: String, approvedBy: String?) {
        logInfo("AppViewModel", "Invite request updated: \(invitationId) status: \(status)")

        // 更新消息列表中对应消息的元数据
        for i in 0..<conversationViewModel.messages.count {
            let msg = conversationViewModel.messages[i]
            if msg.contentType == .inviteRequest, let metadata = msg.metadata,
               metadata["invitation_id"] == invitationId {
                // 更新元数据
                var updatedMetadata = metadata
                updatedMetadata["status"] = status
                if let approvedBy = approvedBy {
                    updatedMetadata["approved_by"] = approvedBy
                }

                // 创建更新后的消息
                let updatedMessage = Message(
                    id: msg.id,
                    conversationId: msg.conversationId,
                    senderType: msg.senderType,
                    senderId: msg.senderId,
                    content: msg.content,
                    contentType: msg.contentType,
                    metadata: updatedMetadata,
                    createdAt: msg.createdAt
                )
                conversationViewModel.messages[i] = updatedMessage
                break
            }
        }
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

        // 设置成员离开回调
        WebSocketService.shared.onMemberLeft = { [weak self] conversationId, userId, userName, systemMessage, newOwnerId, newOwnerName in
            self?.handleMemberLeft(conversationId: conversationId, userId: userId, userName: userName, systemMessage: systemMessage, newOwnerId: newOwnerId, newOwnerName: newOwnerName)
        }

        // 设置新成员加入回调
        WebSocketService.shared.onMemberJoined = { [weak self] conversationId, userId, userName, systemMessage in
            self?.handleMemberJoined(conversationId: conversationId, userId: userId, userName: userName, systemMessage: systemMessage)
        }

        // 设置群邀请回调
        WebSocketService.shared.onGroupInvitation = { [weak self] invitation in
            self?.handleGroupInvitation(invitation)
        }

        // 设置被管理员邀请直接加入群聊回调
        WebSocketService.shared.onGroupJoined = { [weak self] conversationId, conversationName in
            self?.handleGroupJoined(conversationId: conversationId, conversationName: conversationName)
        }

        // 设置群邀请被批准回调
        WebSocketService.shared.onGroupInvitationApproved = { [weak self] invitationId, conversationId in
            self?.handleGroupInvitationApproved(invitationId: invitationId, conversationId: conversationId)
        }

        // 设置群聊解散回调
        WebSocketService.shared.onGroupDissolved = { [weak self] conversationId, conversationName in
            self?.handleGroupDissolved(conversationId: conversationId, conversationName: conversationName)
        }

        // 设置邀请请求状态更新回调
        WebSocketService.shared.onInviteRequestUpdated = { [weak self] conversationId, invitationId, status, approvedBy in
            self?.handleInviteRequestUpdated(conversationId: conversationId, invitationId: invitationId, status: status, approvedBy: approvedBy)
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
        // 设置 ViewModel 之间的引用
        friendshipViewModel.conversationViewModel = conversationViewModel

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