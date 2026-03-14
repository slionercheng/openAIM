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
        } else {
            // 不是当前会话，增加未读数
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
        }

        // 更新会话列表（移到顶部）
        if let index = conversations.firstIndex(where: { $0.id == message.conversationId }) {
            var conv = conversations.remove(at: index)
            // 更新会话的 lastMessage
            conv.lastMessage = message
            if selectedConversation?.id != message.conversationId {
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
    func createConversation(name: String?, type: ConversationType, orgId: String? = nil, participantIds: [String]) async {
        isLoading = true

        do {
            let conversation = try await service.createConversation(
                name: name,
                type: type,
                orgId: orgId,
                participantIds: participantIds
            )
            conversations.insert(conversation, at: 0)
            selectedConversation = conversation
            messages = []
            print("[DEBUG] Conversation created successfully: \(conversation.id)")
        } catch {
            print("[DEBUG] Failed to create conversation: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
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