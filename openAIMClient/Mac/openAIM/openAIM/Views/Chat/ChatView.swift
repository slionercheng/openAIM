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
    }
    
    // MARK: - Chat Header
    
    private var chatHeader: some View {
        HStack(spacing: 12) {
            // 头像
            Circle()
                .fill(Color.blue)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(conversation.name?.prefix(2) ?? "AI")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            
            // 信息
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.name ?? "Conversation")
                    .font(.system(size: 16, weight: .semibold))
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Online")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
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
                }
                .buttonStyle(.plain)
                
                Button {
                    // TODO: 视频通话
                } label: {
                    Image(systemName: "video")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                
                Button {
                    // TODO: 更多
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
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
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(appViewModel.conversationViewModel.messages) { message in
                        MessageBubbleView(message: message)
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
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            TextField("Type a message...", text: $messageText)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .onSubmit {
                    sendMessage()
                }
            
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
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if message.senderType == .agent {
                // AI 头像
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text("AI")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
            
            VStack(alignment: message.senderType == .user ? .trailing : .leading, spacing: 4) {
                // 消息气泡
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundStyle(message.senderType == .user ? .white : .primary)
                    .padding(16)
                    .background(
                        message.senderType == .user
                            ? Color.blue
                            : Color.white
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(message.senderType == .user ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .frame(maxWidth: 450, alignment: message.senderType == .user ? .trailing : .leading)
                
                // 时间
                Text(timeString)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            if message.senderType == .user {
                Spacer()
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