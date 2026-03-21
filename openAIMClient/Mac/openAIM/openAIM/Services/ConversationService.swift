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
    func createConversation(name: String?, type: ConversationType, orgId: String? = nil, isPublic: Bool = false, participantIds: [String]) async throws -> Conversation {
        // 将字符串ID转换为参与者对象
        let participants = participantIds.map { ParticipantIdItem(type: "user", id: $0) }
        let request = CreateConversationRequest(
            name: name,
            type: type,
            orgId: orgId,
            isPublic: isPublic,
            participantIds: participants
        )
        print("[DEBUG] Creating conversation with request: orgId=\(orgId ?? "nil"), type=\(type.rawValue), isPublic=\(isPublic), participants=\(participantIds)")
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

    // MARK: - 群聊搜索

    /// 搜索公开群聊
    func searchPublicGroups(query: String, limit: Int = 20) async throws -> [GroupSearchResult] {
        var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        if !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        let results: [GroupSearchResult] = try await apiClient.get(
            Constants.Conversations.search,
            queryItems: queryItems
        )
        return results
    }

    // MARK: - 加入请求

    /// 申请加入群聊
    func createJoinRequest(conversationId: String, message: String? = nil) async throws -> GroupJoinRequest {
        let request = ["message": message] as [String: String?]
        let result: GroupJoinRequest = try await apiClient.post(Constants.Conversations.joinRequests(conversationId), body: request)
        return result
    }

    /// 获取群聊加入请求列表
    func getJoinRequests(conversationId: String) async throws -> [GroupJoinRequest] {
        let results: [GroupJoinRequest] = try await apiClient.get(Constants.Conversations.joinRequests(conversationId))
        return results
    }

    /// 处理加入请求
    func handleJoinRequest(conversationId: String, requestId: String, action: String) async throws -> GroupJoinRequest {
        let result: GroupJoinRequest = try await apiClient.post(
            "\(Constants.Conversations.joinRequests(conversationId))/\(requestId)/\(action)",
            body: [:] as [String: String?]
        )
        return result
    }

    // MARK: - 群聊管理

    /// 更新群聊设置
    func updateGroupSettings(conversationId: String, name: String?, isPublic: Bool?) async throws -> Conversation {
        struct UpdateGroupSettingsRequest: Encodable {
            let name: String?
            let isPublic: Bool?

            enum CodingKeys: String, CodingKey {
                case name
                case isPublic = "is_public"
            }
        }
        let request = UpdateGroupSettingsRequest(name: name, isPublic: isPublic)
        let result: Conversation = try await apiClient.put(Constants.Conversations.settings(conversationId), body: request)
        return result
    }

    /// 退出群聊
    func leaveConversation(conversationId: String) async throws {
        try await apiClient.delete(Constants.Conversations.detail(conversationId))
    }

    /// 解散群聊
    func dissolveGroup(conversationId: String) async throws {
        try await apiClient.delete("\(Constants.Conversations.detail(conversationId))/dissolve")
    }

    /// 设置成员角色
    func setParticipantRole(conversationId: String, participantId: String, role: ParticipantRole) async throws -> ConversationParticipant {
        let request = ["role": role.rawValue]
        let result: ConversationParticipant = try await apiClient.put(
            "\(Constants.Conversations.participants(conversationId))/\(participantId)/role",
            body: request
        )
        return result
    }

    /// 禁言成员
    func muteParticipant(conversationId: String, participantId: String, duration: Int = 0) async throws -> ConversationParticipant {
        let request = ["duration": duration]
        let result: ConversationParticipant = try await apiClient.post(
            "\(Constants.Conversations.participants(conversationId))/\(participantId)/mute",
            body: request
        )
        return result
    }

    /// 解除禁言
    func unmuteParticipant(conversationId: String, participantId: String) async throws {
        try await apiClient.delete("\(Constants.Conversations.participants(conversationId))/\(participantId)/mute")
    }

    // MARK: - 邀请成员

    /// 邀请成员响应
    struct InviteMemberResponse: Codable {
        let id: String?
        let status: String?
    }

    /// 邀请成员
    func inviteMember(conversationId: String, userId: String) async throws -> InviteMemberResponse {
        let request = ["user_id": userId]
        let result: InviteMemberResponse = try await apiClient.post(Constants.Conversations.invite(conversationId), body: request)
        return result
    }

    /// 获取待审批的邀请
    func getPendingInvitations(conversationId: String) async throws -> [GroupInvitation] {
        let results: [GroupInvitation] = try await apiClient.get(Constants.Conversations.invitations(conversationId))
        return results
    }

    /// 处理邀请审批
    func handleInvitation(conversationId: String, invitationId: String, action: String) async throws -> GroupInvitation {
        let result: GroupInvitation = try await apiClient.post(
            "\(Constants.Conversations.invitations(conversationId))/\(invitationId)/\(action)",
            body: [:] as [String: String?]
        )
        return result
    }

    // MARK: - 用户收到的群邀请

    /// 获取用户收到的群邀请列表
    func getMyInvitations() async throws -> [GroupInvitation] {
        let results: [GroupInvitation] = try await apiClient.get(Constants.Conversations.myInvitations)
        return results
    }

    /// 处理收到的群邀请（接受/拒绝）
    func handleMyInvitation(invitationId: String, action: String) async throws -> GroupInvitation {
        let result: GroupInvitation = try await apiClient.post(
            Constants.Conversations.handleInvitation(invitationId, action: action),
            body: [:] as [String: String?]
        )
        return result
    }
}