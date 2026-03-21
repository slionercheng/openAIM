//
//  ChatView.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import SwiftUI

struct ChatView: View {
    @Environment(AppViewModel.self) private var appViewModel

    let conversation: Conversation

    @State private var messageText = ""
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var isOtherUserOnline = false
    @State private var onlineCheckTask: Task<Void, Never>?
    @State private var showMemberList = false

    /// 获取最新的会话数据（从 ViewModel 获取，保证实时更新）
    private var currentConversation: Conversation {
        if let selected = appViewModel.conversationViewModel.selectedConversation,
           selected.id == conversation.id {
            return selected
        }
        return conversation
    }

    /// 检查群聊是否已解散
    private var isDissolved: Bool {
        appViewModel.dissolvedConversationIds.contains(currentConversation.id) || currentConversation.isDissolved == true
    }

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            chatHeader

            // 消息列表
            messagesView

            // 输入框或解散提示
            if isDissolved {
                // 群聊已解散提示
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("此群聊已解散")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.gray.opacity(0.1))
            } else {
                inputBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
        .onAppear {
            if currentConversation.type == .direct {
                startOnlineStatusCheck()
            }
        }
        .onDisappear {
            stopOnlineStatusCheck()
        }
        .onChange(of: otherParticipant?.id) { _, _ in
            startOnlineStatusCheck()
        }
        .sheet(isPresented: $showMemberList) {
            GroupMembersSheet(conversation: currentConversation)
        }
        
    }

    // MARK: - 当前用户 ID

    private var currentUserId: String? {
        appViewModel.authViewModel.currentUser?.id
    }

    // MARK: - 显示名称

    /// 获取显示名称
    private var displayName: String {
        if currentConversation.type == .group {
            return currentConversation.name ?? "Group Chat"
        } else {
            // 私聊显示对方名字
            if let participants = currentConversation.participants {
                let otherParticipant = participants.first { $0.id != currentUserId }
                if let name = otherParticipant?.name, !name.isEmpty {
                    return name
                }
            }
            return currentConversation.name ?? "Conversation"
        }
    }

    /// 获取显示首字母
    private var displayInitial: String {
        if currentConversation.type == .group {
            return String(currentConversation.name?.prefix(2) ?? "GC")
        } else {
            if let participants = currentConversation.participants {
                let otherParticipant = participants.first { $0.id != currentUserId }
                if let name = otherParticipant?.name, !name.isEmpty {
                    return String(name.prefix(2))
                }
            }
            return String(currentConversation.name?.prefix(2) ?? "AI")
        }
    }

    /// 获取对方用户（私聊）
    private var otherParticipant: ConversationParticipant? {
        guard currentConversation.type == .direct, let participants = currentConversation.participants else {
            return nil
        }
        return participants.first { $0.id != currentUserId }
    }

    /// 获取群成员数量
    private var memberCount: Int {
        currentConversation.participants?.count ?? 0
    }

    // MARK: - Chat Header

    private var chatHeader: some View {
        HStack(spacing: 12) {
            // 头像
            Circle()
                .fill(avatarColor)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(displayInitial)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

            // 信息
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                if currentConversation.type == .direct {
                    // 私聊显示在线状态
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isOtherUserOnline ? Color.green :
                                    Color.gray)
                            .frame(width: 8, height: 8)
                        Text(isOtherUserOnline ? "Online" : "Offline")
                            .font(.system(size: 12))
                            .foregroundStyle(isOtherUserOnline ? Color.green : Color.gray)
                    }
                } else {
                    // 群聊显示成员数
                    Button {
                        showMemberList = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                            Text("\(memberCount) members")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(Color.gray)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // 操作按钮
            HStack(spacing: 16) {
                if currentConversation.type == .group {
                    Button {
                        showMemberList = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    // TODO: 更多
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var avatarColor: Color {
        switch currentConversation.type {
        case .direct: return .blue
        case .group: return .purple
        }
    }

    // MARK: - Messages View

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(appViewModel.conversationViewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            currentUserId: currentUserId,
                            participants: currentConversation.participants,
                            conversationType: currentConversation.type
                        )
                        .id(message.id)
                    }
                }
                .padding(24)
            }
            .onAppear {
                scrollViewProxy = proxy
                if let lastMessage = appViewModel.conversationViewModel.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
            .onChange(of: appViewModel.conversationViewModel.messages.count) { _, _ in
                if let lastMessage = appViewModel.conversationViewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            Button {
                // TODO: 附件
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.gray)
            }
            .buttonStyle(.plain)

            MessageInputField(text: $messageText, onSend: sendMessage)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(messageText.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        let content = messageText
        messageText = ""

        Task {
            await appViewModel.conversationViewModel.sendMessage(content: content)
        }
    }

    // MARK: - 在线状态检查

    private func startOnlineStatusCheck() {
        stopOnlineStatusCheck()

        guard let otherUserId = otherParticipant?.id else { return }

        // 立即检查一次
        Task {
            await checkOnlineStatus(userId: otherUserId)
        }

        // 每10秒检查一次
        onlineCheckTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                if Task.isCancelled { break }
                await checkOnlineStatus(userId: otherUserId)
            }
        }
    }

    private func stopOnlineStatusCheck() {
        onlineCheckTask?.cancel()
        onlineCheckTask = nil
    }

    private func checkOnlineStatus(userId: String) async {
        do {
            let isOnline = try await FriendshipService.shared.getUserOnlineStatus(userId: userId)
            await MainActor.run {
                isOtherUserOnline = isOnline
            }
        } catch {
            logWarn("ChatView", "Failed to check online status: \(error)")
        }
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: Message
    let currentUserId: String?
    let participants: [ConversationParticipant]?
    let conversationType: ConversationType

    /// 判断是否是当前用户发送的消息
    private var isCurrentUser: Bool {
        if message.senderType == .user {
            return message.senderId == currentUserId
        }
        return false
    }

    /// 是否是系统消息
    private var isSystemMessage: Bool {
        message.senderType == .system || message.contentType == .system
    }

    /// 是否是邀请请求消息
    private var isInviteRequest: Bool {
        message.contentType == .inviteRequest
    }

    /// 解析邀请请求元数据
    private var inviteRequestMetadata: InviteRequestMetadata? {
        guard let metadata = message.metadata,
              let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
              let decoded = try? JSONDecoder().decode(InviteRequestMetadata.self, from: jsonData) else {
            return nil
        }
        return decoded
    }

    /// 获取发送者信息
    private var sender: ConversationParticipant? {
        participants?.first { $0.id == message.senderId }
    }

    /// 获取发送者名字
    private var senderName: String? {
        if isCurrentUser {
            return nil  // 自己的消息不显示名字
        }
        // 群聊中显示发送者名字
        if conversationType == .group {
            if message.senderType == .agent {
                return "AI"
            }
            return sender?.name ?? "User"
        }
        // 私聊中，对方消息显示对方名字
        if message.senderType == .user {
            return sender?.name ?? "User"
        }
        return "AI"
    }

    /// 获取头像显示文字
    private var avatarText: String {
        if message.senderType == .agent {
            return "AI"
        }
        if let name = sender?.name, !name.isEmpty {
            return String(name.prefix(1))
        }
        return "U"
    }

    /// 头像颜色
    private var avatarColor: Color {
        if message.senderType == .agent {
            return .purple
        }
        if let name = sender?.name {
            let colors: [Color] = [.blue, .green, .orange, .pink, .cyan, .red]
            let hash = abs(name.hashValue)
            return colors[hash % colors.count]
        }
        return .blue
    }

    var body: some View {
        if isInviteRequest {
            // 邀请请求消息：显示邀请信息和操作按钮
            InviteRequestMessageView(
                message: message,
                metadata: inviteRequestMetadata
            )
        } else if isSystemMessage {
            // 系统消息：居中显示灰色小字
            HStack {
                Spacer()
                Text(message.content)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                Spacer()
            }
            .padding(.vertical, 4)
        } else {
            // 普通消息
            HStack(alignment: .top, spacing: 8) {
                // 左侧头像（对方消息）
                if !isCurrentUser {
                    Circle()
                        .fill(avatarColor)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text(avatarText)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                }

                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                    // 发送者名字（群聊中显示，或私聊中对方消息显示）
                    if !isCurrentUser, let name = senderName {
                        Text(name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.gray)
                    }

                    // 消息气泡
                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundStyle(isCurrentUser ? .white : Color(red: 0.118, green: 0.161, blue: 0.231))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            isCurrentUser
                                ? Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
                                : Color.white
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isCurrentUser ? Color.clear : Color.gray.opacity(0.15), lineWidth: 1)
                        )

                    // 时间
                    Text(timeString)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gray)
                }
                .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)

                // 右侧占位（自己的消息显示头像在右侧）
                if isCurrentUser {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text("我")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                }
            }
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.createdAt)
    }
}

// MARK: - Invite Request Message View

struct InviteRequestMessageView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let message: Message
    let metadata: InviteRequestMetadata?

    @State private var isProcessing = false
    @State private var currentStatus: String = "pending"

    private var isPending: Bool {
        currentStatus == "pending"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 邀请内容
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)

                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
            }

            // 状态显示
            if let meta = metadata {
                if isPending {
                    // 待处理：显示操作按钮
                    HStack(spacing: 12) {
                        Button {
                            handleAction("approve")
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("同意")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isProcessing)

                        Button {
                            handleAction("reject")
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("拒绝")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isProcessing)

                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                } else {
                    // 已处理：显示状态
                    HStack(spacing: 8) {
                        if currentStatus == "approved" {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("已同意")
                                .font(.system(size: 13))
                                .foregroundStyle(.green)
                            if let approvedBy = meta.approvedBy {
                                Text("（由 \(approvedBy) 操作）")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.gray)
                            }
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("已拒绝")
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                            if let approvedBy = meta.approvedBy {
                                Text("（由 \(approvedBy) 操作）")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.95, green: 0.97, blue: 0.98))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .onAppear {
            if let meta = metadata {
                currentStatus = meta.status
            }
        }
        .onChange(of: metadata?.status) { _, newValue in
            if let status = newValue {
                currentStatus = status
            }
        }
    }

    private func handleAction(_ action: String) {
        guard let invitationId = metadata?.invitationId else { return }

        isProcessing = true

        Task {
            do {
                let _ = try await ConversationService.shared.handleInvitation(
                    conversationId: message.conversationId,
                    invitationId: invitationId,
                    action: action
                )

                await MainActor.run {
                    currentStatus = action == "approve" ? "approved" : "rejected"
                    // 刷新会话列表
                    Task {
                        await appViewModel.conversationViewModel.loadConversations()
                    }
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    logError("ChatView", "Failed to handle invitation: \(error)")
                }
            }
        }
    }
}

// MARK: - Group Members Sheet

struct GroupMembersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    let conversation: Conversation

    @State private var showAddMember = false
    @State private var showGroupSettings = false
    @State private var showLeaveConfirm = false
    @State private var showDissolveConfirm = false
    @State private var isLoading = false
    @State private var pendingJoinRequests: [GroupJoinRequest] = []
    @State private var pendingInvitations: [GroupInvitation] = []

    /// 获取最新的会话数据（从 ViewModel 获取，保证实时更新）
    private var currentConversation: Conversation {
        if let selected = appViewModel.conversationViewModel.selectedConversation,
           selected.id == conversation.id {
            return selected
        }
        return conversation
    }

    private var currentUserId: String? {
        appViewModel.authViewModel.currentUser?.id
    }

    private var isOwner: Bool {
        currentConversation.createdBy == currentUserId
    }

    private var isAdmin: Bool {
        guard let participants = currentConversation.participants else { return false }
        let currentParticipant = participants.first { $0.id == currentUserId }
        return currentParticipant?.role == .admin || currentParticipant?.role == .owner || isOwner
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("Group Members")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 待处理请求（仅管理员可见）
            if isAdmin && (!pendingJoinRequests.isEmpty || !pendingInvitations.isEmpty) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pending Approvals")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    // 加入请求
                    ForEach(pendingJoinRequests) { request in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Text(request.user?.name?.prefix(1) ?? "?")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(request.user?.name ?? "User")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Wants to join")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                Button {
                                    Task { await handleJoinRequest(requestId: request.id, action: "accept") }
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task { await handleJoinRequest(requestId: request.id, action: "reject") }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // 邀请审批
                    ForEach(pendingInvitations) { invitation in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Text(invitation.invitee?.name?.prefix(1) ?? "?")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(invitation.invitee?.name ?? "User")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Invited by \(invitation.inviter?.name ?? "someone")")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                Button {
                                    Task { await handleInvitation(invitationId: invitation.id, action: "approve") }
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task { await handleInvitation(invitationId: invitation.id, action: "reject") }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))

                Divider()
            }

            // 成员列表
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(currentConversation.participants ?? [], id: \.id) { participant in
                        GroupMemberRow(
                            participant: participant,
                            conversation: currentConversation,
                            isOwner: isOwner,
                            isAdmin: isAdmin,
                            currentUserId: currentUserId
                        )
                    }
                }
                .padding()
            }

            Divider()

            // 操作按钮
            VStack(spacing: 12) {
                // 添加成员按钮
                Button {
                    showAddMember = true
                } label: {
                    Label("Add Member", systemImage: "person.badge.plus")
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                // 群设置（仅群主可见）
                if isOwner {
                    Button {
                        showGroupSettings = true
                    } label: {
                        Label("Group Settings", systemImage: "gearshape.fill")
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                // 退出群聊
                Button {
                    showLeaveConfirm = true
                } label: {
                    Label("Leave Group", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                // 解散群聊（仅群主或管理员可见）
                if isAdmin {
                    Button {
                        showDissolveConfirm = true
                    } label: {
                        Label("Dissolve Group", systemImage: "xmark.bin.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .frame(width: 400, height: 600)
        .sheet(isPresented: $showAddMember) {
            AddMemberSheet(conversation: currentConversation)
        }
        .sheet(isPresented: $showGroupSettings) {
            GroupSettingsSheet(conversation: currentConversation)
        }
        .alert("Leave Group", isPresented: $showLeaveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task { await leaveGroup() }
            }
        } message: {
            Text("Are you sure you want to leave this group?")
        }
        .alert("Dissolve Group", isPresented: $showDissolveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Dissolve", role: .destructive) {
                Task { await dissolveGroup() }
            }
        } message: {
            Text("Are you sure you want to dissolve this group? This action cannot be undone.")
        }
        .task {
            if isAdmin {
                await loadPendingItems()
            }
        }
    }

    private func loadPendingItems() async {
        do {
            pendingJoinRequests = try await ConversationService.shared.getJoinRequests(conversationId: currentConversation.id)
            pendingInvitations = try await ConversationService.shared.getPendingInvitations(conversationId: currentConversation.id)
        } catch {
            print("[ERROR] Failed to load pending items: \(error)")
        }
    }

    private func handleJoinRequest(requestId: String, action: String) async {
        do {
            _ = try await ConversationService.shared.handleJoinRequest(
                conversationId: currentConversation.id,
                requestId: requestId,
                action: action
            )
            await loadPendingItems()
            await appViewModel.conversationViewModel.loadConversations()
        } catch {
            print("[ERROR] Failed to handle join request: \(error)")
        }
    }

    private func handleInvitation(invitationId: String, action: String) async {
        do {
            _ = try await ConversationService.shared.handleInvitation(
                conversationId: currentConversation.id,
                invitationId: invitationId,
                action: action
            )
            await loadPendingItems()
            await appViewModel.conversationViewModel.loadConversations()
        } catch {
            print("[ERROR] Failed to handle invitation: \(error)")
        }
    }

    private func leaveGroup() async {
        do {
            try await ConversationService.shared.leaveConversation(conversationId: currentConversation.id)
            appViewModel.conversationViewModel.selectedConversation = nil
            await appViewModel.conversationViewModel.loadConversations()
            dismiss()
        } catch {
            print("[ERROR] Failed to leave group: \(error)")
        }
    }

    private func dissolveGroup() async {
        do {
            try await ConversationService.shared.dissolveGroup(conversationId: currentConversation.id)
            appViewModel.conversationViewModel.selectedConversation = nil
            await appViewModel.conversationViewModel.loadConversations()
            dismiss()
        } catch {
            print("[ERROR] Failed to dissolve group: \(error)")
        }
    }

    private func participantAvatarColor(_ participant: ConversationParticipant) -> Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = abs((participant.name ?? participant.id).hashValue)
        return colors[hash % colors.count]
    }

    private func participantInitial(_ participant: ConversationParticipant) -> String {
        if let name = participant.name, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return String(participant.id.prefix(1)).uppercased()
    }
}

// MARK: - Group Member Row

struct GroupMemberRow: View {
    @Environment(AppViewModel.self) private var appViewModel

    let participant: ConversationParticipant
    let conversation: Conversation
    let isOwner: Bool
    let isAdmin: Bool
    let currentUserId: String?

    @State private var showRoleMenu = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(avatarColor)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(initial)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(participant.name ?? "User")
                        .font(.system(size: 14, weight: .medium))

                    // 角色标签
                    if let role = participant.role {
                        roleBadge(role)
                    }

                    // 禁言标签
                    if participant.isMuted == true {
                        Text("Muted")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                }

                if participant.id == currentUserId {
                    Text("You")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            // 管理按钮（仅群主/管理员可操作非群主成员）
            if isOwner && participant.id != currentUserId && participant.role != .owner {
                Menu {
                    // 设置角色
                    if participant.role != .admin {
                        Button {
                            Task { await setRole(.admin) }
                        } label: {
                            Label("Set as Admin", systemImage: "crown.fill")
                        }
                    }
                    if participant.role != .member {
                        Button {
                            Task { await setRole(.member) }
                        } label: {
                            Label("Set as Member", systemImage: "person.fill")
                        }
                    }

                    Divider()

                    // 禁言/解禁
                    if participant.isMuted == true {
                        Button {
                            Task { await unmute() }
                        } label: {
                            Label("Unmute", systemImage: "speaker.wave.2.fill")
                        }
                    } else {
                        Menu {
                            Button { Task { await mute(duration: 0) } } label: { Text("Permanent") }
                            Button { Task { await mute(duration: 60) } } label: { Text("1 Hour") }
                            Button { Task { await mute(duration: 1440) } } label: { Text("1 Day") }
                            Button { Task { await mute(duration: 10080) } } label: { Text("1 Week") }
                        } label: {
                            Label("Mute", systemImage: "speaker.slash.fill")
                        }
                    }

                    Divider()

                    // 移除成员
                    Button(role: .destructive) {
                        Task { await removeMember() }
                    } label: {
                        Label("Remove", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func roleBadge(_ role: ParticipantRole) -> some View {
        switch role {
        case .owner:
            Text("Owner")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple)
                .cornerRadius(4)
        case .admin:
            Text("Admin")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue)
                .cornerRadius(4)
        case .member:
            EmptyView()
        }
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = abs((participant.name ?? participant.id).hashValue)
        return colors[hash % colors.count]
    }

    private var initial: String {
        if let name = participant.name, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return String(participant.id.prefix(1)).uppercased()
    }

    private func setRole(_ role: ParticipantRole) async {
        do {
            _ = try await ConversationService.shared.setParticipantRole(
                conversationId: conversation.id,
                participantId: participant.id,
                role: role
            )
            await appViewModel.conversationViewModel.loadConversations()
        } catch {
            print("[ERROR] Failed to set role: \(error)")
        }
    }

    private func mute(duration: Int) async {
        do {
            _ = try await ConversationService.shared.muteParticipant(
                conversationId: conversation.id,
                participantId: participant.id,
                duration: duration
            )
            await appViewModel.conversationViewModel.loadConversations()
        } catch {
            print("[ERROR] Failed to mute: \(error)")
        }
    }

    private func unmute() async {
        do {
            try await ConversationService.shared.unmuteParticipant(
                conversationId: conversation.id,
                participantId: participant.id
            )
            await appViewModel.conversationViewModel.loadConversations()
        } catch {
            print("[ERROR] Failed to unmute: \(error)")
        }
    }

    private func removeMember() async {
        do {
            try await ConversationService.shared.removeParticipant(
                conversationId: conversation.id,
                participantId: participant.id
            )
            await appViewModel.conversationViewModel.loadConversations()
        } catch {
            print("[ERROR] Failed to remove member: \(error)")
        }
    }
}

// MARK: - Group Settings Sheet

struct GroupSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    let conversation: Conversation

    @State private var groupName: String
    @State private var isPublic: Bool
    @State private var isLoading = false

    init(conversation: Conversation) {
        self.conversation = conversation
        _groupName = State(initialValue: conversation.name ?? "")
        _isPublic = State(initialValue: conversation.isPublic ?? false)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("Group Settings")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 设置表单
            Form {
                Section("Basic Info") {
                    TextField("Group Name", text: $groupName)

                    Toggle("Public Group", isOn: $isPublic)
                    Text("Public groups can be discovered and joined by anyone")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Spacer()

            Divider()

            // 按钮
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await saveSettings() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || groupName.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }

    private func saveSettings() async {
        isLoading = true
        do {
            _ = try await ConversationService.shared.updateGroupSettings(
                conversationId: conversation.id,
                name: groupName,
                isPublic: isPublic
            )
            await appViewModel.conversationViewModel.loadConversations()
            dismiss()
        } catch {
            print("[ERROR] Failed to save settings: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Add Member Sheet

struct AddMemberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    let conversation: Conversation

    @State private var selectedUserIds: Set<String> = []
    @State private var isLoading = false

    /// 获取最新的会话数据（从 ViewModel 获取，保证实时更新）
    private var currentConversation: Conversation {
        if let selected = appViewModel.conversationViewModel.selectedConversation,
           selected.id == conversation.id {
            return selected
        }
        return conversation
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("Add Members")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if availableMembers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)

                    Text("No members available to add")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(availableMembers) { user in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(avatarColor(user))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Text(avatarInitial(user))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.name ?? user.email)
                                        .font(.system(size: 14, weight: .medium))

                                    Text(user.email)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    toggleSelection(user.id)
                                } label: {
                                    Image(systemName: selectedUserIds.contains(user.id) ? "checkmark.circle.fill" : "plus.circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(selectedUserIds.contains(user.id) ? .blue : .gray)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(selectedUserIds.contains(user.id) ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // 按钮
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("Add") {
                    Task {
                        await addMembers()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedUserIds.isEmpty || isLoading)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
    }

    /// 可添加的成员（好友中不在会话中的）
    private var availableMembers: [User] {
        let currentParticipantIds = Set(currentConversation.participants?.map { $0.id } ?? [])
        return appViewModel.friendshipViewModel.friends
            .compactMap { $0.user }
            .filter { !currentParticipantIds.contains($0.id) }
    }

    private func toggleSelection(_ userId: String) {
        if selectedUserIds.contains(userId) {
            selectedUserIds.remove(userId)
        } else {
            selectedUserIds.insert(userId)
        }
    }

    private func addMembers() async {
        isLoading = true

        for userId in selectedUserIds {
            do {
                _ = try await ConversationService.shared.inviteMember(
                    conversationId: currentConversation.id,
                    userId: userId
                )
            } catch {
                logError("AddMemberSheet", "Failed to invite member: \(error)")
            }
        }

        // 刷新会话信息
        await appViewModel.conversationViewModel.loadConversations()

        isLoading = false
        dismiss()
    }

    private func avatarColor(_ user: User) -> Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = abs((user.name ?? user.id).hashValue)
        return colors[hash % colors.count]
    }

    private func avatarInitial(_ user: User) -> String {
        if let name = user.name, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return String(user.email.prefix(1)).uppercased()
    }
}

#Preview {
    ChatView(conversation: Conversation(
        id: "1",
        name: "AI Assistant",
        type: .direct,
        organizationId: nil,
        isPublic: false,
        createdBy: "user",
        createdAt: Date(),
        updatedAt: Date(),
        unreadCount: 0
    ))
    .environment(AppViewModel())
}

// MARK: - Message Input Field

struct MessageInputField: View {
    @Binding var text: String
    var onSend: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                .tint(Color.blue)
                .padding(12)
                .background(Color(red: 0.945, green: 0.961, blue: 0.969))
                .cornerRadius(12)
                .onSubmit {
                    onSend()
                }

            if text.isEmpty {
                Text("Type a message...")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.58, green: 0.64, blue: 0.72))
                    .padding(.leading, 12)
                    .allowsHitTesting(false)
            }
        }
    }
}
