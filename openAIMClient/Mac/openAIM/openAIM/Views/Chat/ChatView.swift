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

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            chatHeader

            // 消息列表
            messagesView

            // 输入框
            inputBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
        .onAppear {
            startOnlineStatusCheck()
        }
        .onDisappear {
            stopOnlineStatusCheck()
        }
        .onChange(of: otherParticipant?.id) { _, _ in
            startOnlineStatusCheck()
        }
    }

    // MARK: - 当前用户 ID

    private var currentUserId: String? {
        appViewModel.authViewModel.currentUser?.id
    }

    // MARK: - 对方信息

    /// 获取对方的名字（用于 direct 类型会话）
    private var displayName: String {
        if conversation.type == .direct, let participants = conversation.participants {
            let otherParticipant = participants.first { $0.id != currentUserId }
            if let name = otherParticipant?.name, !name.isEmpty {
                return name
            }
        }
        return conversation.name ?? "Conversation"
    }

    /// 获取对方的头像首字母
    private var displayInitial: String {
        if conversation.type == .direct, let participants = conversation.participants {
            let otherParticipant = participants.first { $0.id != currentUserId }
            if let name = otherParticipant?.name, !name.isEmpty {
                return String(name.prefix(2))
            }
        }
        return String(conversation.name?.prefix(2) ?? "AI")
    }

    /// 获取对方用户
    private var otherParticipant: ConversationParticipant? {
        guard conversation.type == .direct, let participants = conversation.participants else {
            return nil
        }
        return participants.first { $0.id != currentUserId }
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

                HStack(spacing: 4) {
                    Circle()
                        .fill(isOtherUserOnline ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(isOtherUserOnline ? "Online" : "Offline")
                        .font(.system(size: 12))
                        .foregroundStyle(isOtherUserOnline ? Color.green : Color.gray)
                }
            }

            Spacer()

            // 操作按钮
            HStack(spacing: 16) {
                Button {
                    // TODO: 语音通话
                } label: {
                    Image(systemName: "phone")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Button {
                    // TODO: 视频通话
                } label: {
                    Image(systemName: "video")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

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
        switch conversation.type {
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
                            otherParticipant: otherParticipant
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
    let otherParticipant: ConversationParticipant?

    /// 判断是否是当前用户发送的消息
    private var isCurrentUser: Bool {
        // 如果 senderType 是 user，通过 senderId 判断是否是当前用户
        if message.senderType == .user {
            return message.senderId == currentUserId
        }
        // agent 发送的消息不是当前用户
        return false
    }

    /// 获取发送者名字
    private var senderName: String? {
        if isCurrentUser {
            return nil  // 自己的消息不显示名字
        }
        // 对方的消息，显示对方名字
        if message.senderType == .user {
            return otherParticipant?.name ?? "User"
        } else {
            return "AI"
        }
    }

    /// 获取头像显示文字
    private var avatarText: String {
        if message.senderType == .agent {
            return "AI"
        }
        if let name = otherParticipant?.name, !name.isEmpty {
            return String(name.prefix(1))
        }
        return "U"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 左侧头像（对方消息）
            if !isCurrentUser {
                Circle()
                    .fill(message.senderType == .agent ? Color.purple : Color.blue)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(avatarText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // 发送者名字（仅对方消息显示）
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

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.createdAt)
    }
}

#Preview {
    ChatView(conversation: Conversation(
        id: "1",
        name: "AI Assistant",
        type: .direct,
        organizationId: nil,
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