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
    
    private let service = ConversationService.shared
    
    /// 加载会话列表
    func loadConversations() async {
        isLoading = true
        errorMessage = nil
        
        do {
            conversations = try await service.getConversations()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// 选择会话
    func selectConversation(_ conversation: Conversation) async {
        selectedConversation = conversation
        await loadMessages(conversationId: conversation.id)
    }
    
    /// 加载消息
    func loadMessages(conversationId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await service.getMessages(conversationId: conversationId)
            messages = response.messages.reversed()
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 创建会话
    func createConversation(name: String?, type: ConversationType, participantIds: [String]) async {
        isLoading = true
        
        do {
            let conversation = try await service.createConversation(
                name: name,
                type: type,
                organizationId: nil,
                participantIds: participantIds
            )
            conversations.insert(conversation, at: 0)
            selectedConversation = conversation
            messages = []
        } catch {
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