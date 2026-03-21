//
//  ConversationViewModel.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation
import SwiftUI

/// 会话视图模型
@MainActor
@Observable
class ConversationViewModel {
    var conversations: [Conversation] = []
    var selectedConversation: Conversation?
    var messages: [Message] = []
    var isLoading = false
    var errorMessage: String?

    // 新消息通知回调
    var onNewMessage: ((Message, String) -> Void)?  // message, conversationName

    // 本地存储的最新消息和未读数（用于 UI 显示）
    private(set) var latestMessages: [String: Message] = [:]  // conversationId -> Message
    private(set) var unreadCounts: [String: Int] = [:]  // conversationId -> count

    private let service = ConversationService.shared

    /// 处理 WebSocket 收到的新消息
    func handleNewMessage(_ message: Message) {
        logDebug("ConversationViewModel", "handleNewMessage called, conversationId: \(message.conversationId), selectedConversation: \(selectedConversation?.id ?? "nil")")

        // 更新最新消息
        latestMessages[message.conversationId] = message

        // 判断是否是系统消息
        let isSystemMessage = message.senderType == .system || message.contentType == .system

        // 如果是当前会话的消息，添加到消息列表
        if selectedConversation?.id == message.conversationId {
            logInfo("ConversationViewModel", "Match! Adding message to list")
            // 检查消息是否已存在（避免重复）
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
                logInfo("ConversationViewModel", "Message added. Total messages: \(messages.count)")

                // 保存到工作区
                WorkspaceManager.shared.saveMessages(conversationId: message.conversationId, messages: messages)
            } else {
                logDebug("ConversationViewModel", "Message already exists, skipping")
            }
        } else if !isSystemMessage {
            // 不是当前会话，且不是系统消息，才增加未读数
            // 系统消息不计入未读计数（如"xxx 加入了群聊"只是通知性质）
            let currentCount = unreadCounts[message.conversationId] ?? 0
            unreadCounts[message.conversationId] = currentCount + 1
            logInfo("ConversationViewModel", "Unread count for \(message.conversationId): \(currentCount + 1)")

            // 保存未读数到工作区
            WorkspaceManager.shared.saveUnreadCounts(unreadCounts)

            // 发送新消息通知
            let conversationName = getConversationName(message.conversationId)
            onNewMessage?(message, conversationName)

            // 仍然保存消息到工作区（后台保存）
            var existingMessages = WorkspaceManager.shared.loadMessages(conversationId: message.conversationId)
            if !existingMessages.contains(where: { $0.id == message.id }) {
                existingMessages.append(message)
                WorkspaceManager.shared.saveMessages(conversationId: message.conversationId, messages: existingMessages)
            }
        } else {
            // 系统消息：保存到工作区，但不增加未读计数
            logInfo("ConversationViewModel", "System message received, not incrementing unread count")
            var existingMessages = WorkspaceManager.shared.loadMessages(conversationId: message.conversationId)
            if !existingMessages.contains(where: { $0.id == message.id }) {
                existingMessages.append(message)
                WorkspaceManager.shared.saveMessages(conversationId: message.conversationId, messages: existingMessages)
            }
        }

        // 更新会话列表（移到顶部）
        if let index = conversations.firstIndex(where: { $0.id == message.conversationId }) {
            var conv = conversations.remove(at: index)
            // 更新会话的 lastMessage
            conv.lastMessage = message
            // 只有非系统消息且不是当前会话时才增加未读计数
            if !isSystemMessage && selectedConversation?.id != message.conversationId {
                conv.unreadCount = (conv.unreadCount ?? 0) + 1
            }
            conversations.insert(conv, at: 0)
            logInfo("ConversationViewModel", "Moved conversation to top")

            // 保存会话列表到工作区
            WorkspaceManager.shared.saveConversations(conversations)
        }
    }

    /// 获取会话名称
    private func getConversationName(_ conversationId: String) -> String {
        if let conv = conversations.first(where: { $0.id == conversationId }) {
            return conv.name ?? getParticipantNames(conv)
        }
        return "Unknown"
    }

    /// 获取参与者名称
    private func getParticipantNames(_ conversation: Conversation) -> String {
        guard let participants = conversation.participants else { return "Chat" }
        let names = participants.compactMap { $0.name }.joined(separator: ", ")
        return names.isEmpty ? "Chat" : names
    }

    /// 获取会话的最新消息预览
    func getLatestMessagePreview(_ conversationId: String) -> String? {
        if let message = latestMessages[conversationId] {
            return message.content
        }
        if let conv = conversations.first(where: { $0.id == conversationId }),
           let lastMsg = conv.lastMessage {
            return lastMsg.content
        }
        return nil
    }

    /// 获取会话的未读数
    func getUnreadCount(_ conversationId: String) -> Int {
        return unreadCounts[conversationId] ?? conversations.first(where: { $0.id == conversationId })?.unreadCount ?? 0
    }

    /// 清除会话的未读数
    func clearUnreadCount(_ conversationId: String) {
        unreadCounts[conversationId] = 0
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].unreadCount = 0
        }
        // 保存未读数到工作区
        WorkspaceManager.shared.saveUnreadCounts(unreadCounts)
    }

    /// 清除所有未读数
    func clearAllUnreadCounts() {
        for conversationId in unreadCounts.keys {
            unreadCounts[conversationId] = 0
        }
        for i in 0..<conversations.count {
            conversations[i].unreadCount = 0
        }
        // 保存未读数到工作区
        WorkspaceManager.shared.saveUnreadCounts(unreadCounts)
        logInfo("ConversationViewModel", "Cleared all unread counts")
    }

    /// 总未读数
    var totalUnreadCount: Int {
        return unreadCounts.values.reduce(0, +)
    }

    /// 清除所有数据（用于切换用户时）
    func clearData() {
        conversations = []
        selectedConversation = nil
        messages = []
        latestMessages = [:]
        unreadCounts = [:]
        errorMessage = nil
        logInfo("ConversationViewModel", "Data cleared")
    }

    /// 加载会话列表
    func loadConversations() async {
        isLoading = true
        errorMessage = nil

        do {
            conversations = try await service.getConversations()

            // 为每个会话从工作区加载最后一条消息
            for i in 0..<conversations.count {
                let messages = WorkspaceManager.shared.loadMessages(conversationId: conversations[i].id)
                if let lastMsg = messages.last {
                    conversations[i].lastMessage = lastMsg
                }
            }

            // 从工作区加载未读数
            unreadCounts = WorkspaceManager.shared.loadUnreadCounts()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
    
    /// 选择会话
    func selectConversation(_ conversation: Conversation) async {
        selectedConversation = conversation
        // 清除该会话的未读数
        clearUnreadCount(conversation.id)
        await loadMessages(conversationId: conversation.id)
    }
    
    /// 加载消息
    func loadMessages(conversationId: String) async {
        isLoading = true
        errorMessage = nil

        // 先从工作区加载本地消息（立即显示）
        let localMessages = WorkspaceManager.shared.loadMessages(conversationId: conversationId)
        if !localMessages.isEmpty {
            messages = localMessages
            logInfo("ConversationViewModel", "Loaded \(localMessages.count) messages from workspace for conversation: \(conversationId)")
        }

        // 从服务器加载消息
        do {
            let response = try await service.getMessages(conversationId: conversationId)
            messages = response.list.reversed()

            // 保存到工作区
            WorkspaceManager.shared.saveMessages(conversationId: conversationId, messages: messages)
            logInfo("ConversationViewModel", "Saved \(messages.count) messages to workspace for conversation: \(conversationId)")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
    
    /// 发送消息
    func sendMessage(content: String) async {
        guard let conversationId = selectedConversation?.id, !content.isEmpty else { return }

        do {
            let message = try await service.sendMessage(conversationId: conversationId, content: content)
            messages.append(message)

            // 保存到工作区
            WorkspaceManager.shared.saveMessages(conversationId: conversationId, messages: messages)
            logInfo("ConversationViewModel", "Message sent and saved to workspace")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 创建会话
    func createConversation(name: String?, type: ConversationType, orgId: String? = nil, isPublic: Bool = false, participantIds: [String]) async -> Bool {
        isLoading = true

        // 如果是私聊，先检查是否已存在与该用户的会话（客户端本地检查）
        if type == .direct && participantIds.count == 1 {
            let targetUserId = participantIds[0]
            if let existingConv = findDirectConversation(with: targetUserId) {
                // 已存在，直接选中该会话
                logInfo("ConversationViewModel", "Found existing direct conversation locally with user: \(targetUserId)")
                selectedConversation = existingConv
                messages = []
                await loadMessages(conversationId: existingConv.id)
                isLoading = false
                return false // 返回 false 表示没有创建新会话
            }
        }

        do {
            let conversation = try await service.createConversation(
                name: name,
                type: type,
                orgId: orgId,
                isPublic: isPublic,
                participantIds: participantIds
            )

            // 检查服务端是否返回了已存在的会话
            if conversation.existing == true {
                logInfo("ConversationViewModel", "Server returned existing conversation: \(conversation.id)")
                // 在列表中查找并选中该会话
                if let existingConv = conversations.first(where: { $0.id == conversation.id }) {
                    selectedConversation = existingConv
                } else {
                    // 会话不在本地列表中，添加并选中
                    conversations.insert(conversation, at: 0)
                    selectedConversation = conversation
                }
                messages = []
                await loadMessages(conversationId: conversation.id)
                isLoading = false
                return false // 返回 false 表示没有创建新会话
            }

            conversations.insert(conversation, at: 0)
            selectedConversation = conversation
            messages = []
            logInfo("ConversationViewModel", "Conversation created successfully: \(conversation.id)")
            isLoading = false
            return true // 返回 true 表示创建了新会话
        } catch {
            logError("ConversationViewModel", "Failed to create conversation: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// 查找与指定用户的私聊会话
    func findDirectConversation(with userId: String) -> Conversation? {
        guard let currentUserId = SessionManager.shared.currentUserId else { return nil }

        for conv in conversations {
            if conv.type == .direct {
                // 检查参与者是否包含该用户
                if let participants = conv.participants {
                    let hasTargetUser = participants.contains { $0.id == userId }
                    let hasCurrentUser = participants.contains { $0.id == currentUserId }
                    if hasTargetUser && hasCurrentUser && participants.count == 2 {
                        return conv
                    }
                }
            }
        }
        return nil
    }
    
    /// 删除会话
    func deleteConversation(_ conversation: Conversation) async {
        do {
            try await service.deleteConversation(id: conversation.id)
            conversations.removeAll { $0.id == conversation.id }
            if selectedConversation?.id == conversation.id {
                selectedConversation = nil
                messages = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}