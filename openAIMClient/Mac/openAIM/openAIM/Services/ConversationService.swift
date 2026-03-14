//
//  ConversationService.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation

/// 会话服务
actor ConversationService {
    static let shared = ConversationService()
    
    private let apiClient = APIClient.shared
    
    private init() {}
    
    /// 获取会话列表
    func getConversations() async throws -> [Conversation] {
        let conversations: [Conversation] = try await apiClient.get(Constants.Conversations.base)
        return conversations
    }
    
    /// 获取会话详情
    func getConversation(id: String) async throws -> Conversation {
        let conversation: Conversation = try await apiClient.get(Constants.Conversations.detail(id))
        return conversation
    }
    
    /// 创建会话
    func createConversation(name: String?, type: ConversationType, orgId: String? = nil, participantIds: [String]) async throws -> Conversation {
        // 将字符串ID转换为参与者对象
        let participants = participantIds.map { ParticipantIdItem(type: "user", id: $0) }
        let request = CreateConversationRequest(
            name: name,
            type: type,
            orgId: orgId,
            participantIds: participants
        )
        print("[DEBUG] Creating conversation with request: orgId=\(orgId ?? "nil"), type=\(type.rawValue), participants=\(participantIds)")
        let conversation: Conversation = try await apiClient.post(Constants.Conversations.base, body: request)
        return conversation
    }
    
    /// 更新会话
    func updateConversation(id: String, name: String?) async throws -> Conversation {
        let request = ["name": name]
        let conversation: Conversation = try await apiClient.put(Constants.Conversations.detail(id), body: request)
        return conversation
    }
    
    /// 删除会话
    func deleteConversation(id: String) async throws {
        try await apiClient.delete(Constants.Conversations.detail(id))
    }
    
    /// 获取消息列表
    func getMessages(conversationId: String, page: Int = 1, pageSize: Int = 50) async throws -> MessageListResponse {
        let queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        let response: MessageListResponse = try await apiClient.get(
            Constants.Conversations.messages(conversationId),
            queryItems: queryItems
        )
        return response
    }
    
    /// 发送消息
    func sendMessage(conversationId: String, content: String, contentType: ContentType = .text) async throws -> Message {
        let request = SendMessageRequest(content: content, contentType: contentType, metadata: nil)
        let message: Message = try await apiClient.post(Constants.Conversations.messages(conversationId), body: request)
        return message
    }
    
    /// 添加参与者
    func addParticipant(conversationId: String, participantType: ParticipantType, participantId: String) async throws -> Participant {
        let request = AddParticipantRequest(participantType: participantType, participantId: participantId)
        let participant: Participant = try await apiClient.post(Constants.Conversations.participants(conversationId), body: request)
        return participant
    }
    
    /// 移除参与者
    func removeParticipant(conversationId: String, participantId: String) async throws {
        try await apiClient.delete("\(Constants.Conversations.participants(conversationId))/\(participantId)")
    }
}