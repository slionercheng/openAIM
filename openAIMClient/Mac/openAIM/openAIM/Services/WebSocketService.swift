//
//  WebSocketService.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation

/// WebSocket 消息类型
enum WSMessageType: String, Codable {
    case newMessage = "new_message"
    case messageRead = "message_read"
    case userOnline = "user_online"
    case userOffline = "user_offline"
    case typing = "typing"
    case ping = "ping"
    case pong = "pong"
    case heartbeat = "heartbeat"
    case kicked = "kicked"
    case alreadyOnline = "already_online"
    case forceLogin = "force_login"
    case loginSuccess = "login_success"
    case memberLeft = "member_left"
    case memberJoined = "member_joined"
    case groupInvitation = "group_invitation"
    case groupJoined = "group_joined"
    case groupInvitationApproved = "group_invitation_approved"
    case groupDissolved = "group_dissolved"
}

/// WebSocket 接收到的消息（服务端格式）
struct WSReceivedMessage: Codable {
    let type: String
    let id: String?
    let conversationId: String?
    let senderType: String?
    let senderId: String?
    let senderName: String?
    let senderAvatar: String?
    let content: String?
    let contentType: String?
    let createdAtString: String?
    // 群邀请相关字段
    let conversationName: String?
    let inviterId: String?
    let inviterName: String?
    let inviteeId: String?
    let status: String?
    let invitationId: String?  // 邀请ID
    let approvedBy: String?  // 审批人
    // 新成员加入相关字段
    let userId: String?
    let userName: String?
    let userAvatar: String?
    // 新群主字段（群主转让时）
    let newOwnerId: String?
    let newOwnerName: String?
    // 系统消息字段
    let systemMessage: SystemMessageData?

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case conversationId = "conversation_id"
        case senderType = "sender_type"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case senderAvatar = "sender_avatar"
        case content
        case contentType = "content_type"
        case createdAtString = "created_at"
        case conversationName = "conversation_name"
        case inviterId = "inviter_id"
        case inviterName = "inviter_name"
        case inviteeId = "invitee_id"
        case status
        case invitationId = "invitation_id"
        case approvedBy = "approved_by"
        case userId = "user_id"
        case userName = "user_name"
        case userAvatar = "user_avatar"
        case newOwnerId = "new_owner_id"
        case newOwnerName = "new_owner_name"
        case systemMessage = "system_message"
    }

    /// 系统消息数据
    struct SystemMessageData: Codable {
        let id: String
        let content: String
        let createdAtString: String?

        enum CodingKeys: String, CodingKey {
            case id
            case content
            case createdAtString = "created_at"
        }

        var createdAt: Date {
            if let dateString = createdAtString {
                return Self.parseDate(dateString) ?? Date()
            }
            return Date()
        }

        private static func parseDate(_ dateString: String) -> Date? {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: dateString)
        }
    }

    /// 解析日期
    private static func parseDate(_ dateString: String) -> Date? {
        // 尝试多种日期格式
        let formatters: [ISO8601DateFormatter] = {
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let withoutFractional = ISO8601DateFormatter()
            withoutFractional.formatOptions = [.withInternetDateTime]

            return [withFractional, withoutFractional]
        }()

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        // 尝试自定义格式
        let customFormatter = DateFormatter()
        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        if let date = customFormatter.date(from: dateString) {
            return date
        }

        customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        if let date = customFormatter.date(from: dateString) {
            return date
        }

        return nil
    }

    /// 转换为 Message 对象
    func toMessage() -> Message? {
        guard let id = id,
              let conversationId = conversationId,
              let senderType = senderType,
              let senderId = senderId,
              let content = content,
              let contentType = contentType else {
            logWarn("WebSocket", "toMessage failed: missing required fields")
            return nil
        }

        let createdAt: Date
        if let dateString = createdAtString, let date = Self.parseDate(dateString) {
            createdAt = date
        } else {
            logDebug("WebSocket", "toMessage: using current date as fallback")
            createdAt = Date()
        }

        return Message(
            id: id,
            conversationId: conversationId,
            senderType: SenderType(rawValue: senderType) ?? .user,
            senderId: senderId,
            content: content,
            contentType: ContentType(rawValue: contentType) ?? .text,
            metadata: nil,
            createdAt: createdAt
        )
    }
}

/// WebSocket 服务
@MainActor
@Observable
class WebSocketService: NSObject {
    static let shared = WebSocketService()

    // MARK: - Published Properties

    var isConnected = false
    var connectionError: String?

    // MARK: - Private Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?  // 保持 session 的强引用
    private var timer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var isConnecting = false  // 防止重复连接
    private var shouldReconnect = true  // 是否应该重连

    // MARK: - Callbacks

    var onMessageReceived: ((Message) -> Void)?
    var onUserOnline: ((String) -> Void)?
    var onUserOffline: ((String) -> Void)?
    var onTyping: ((String, Bool) -> Void)?
    var onKicked: (() -> Void)?  // 被踢下线回调
    var onAlreadyOnline: (() -> Void)?  // 检测到已有在线设备，需要确认
    var onMemberLeft: ((String, String, String, (id: String, content: String, createdAt: Date)?, String?, String?) -> Void)?  // conversationId, userId, userName, systemMessage, newOwnerId, newOwnerName 成员离开回调
    var onMemberJoined: ((String, String, String, (id: String, content: String, createdAt: Date)?) -> Void)?  // conversationId, userId, userName, systemMessage 成员加入回调
    var onGroupInvitation: ((GroupInvitation) -> Void)?  // 收到群邀请
    var onGroupJoined: ((String, String) -> Void)?  // conversationId, conversationName 被管理员邀请直接加入
    var onGroupInvitationApproved: ((String, String) -> Void)?  // invitationId, conversationId 邀请被批准
    var onGroupDissolved: ((String, String) -> Void)?  // conversationId, conversationName 群聊解散
    var onInviteRequestUpdated: ((String, String, String, String?) -> Void)?  // conversationId, invitationId, status, approvedBy 邀请请求状态更新

    // 存储当前 token 用于强制登录
    private var currentToken: String?

    // MARK: - Private Properties

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// 连接 WebSocket
    func connect(token: String) {
        // 如果正在连接或已连接，跳过
        if isConnecting {
            logInfo("WebSocket", "Already connecting, skipping...")
            return
        }

        if isConnected {
            logInfo("WebSocket", "Already connected, skipping...")
            return
        }

        isConnecting = true
        shouldReconnect = true
        reconnectAttempts = 0
        currentToken = token  // 存储 token 用于可能的强制登录

        logInfo("WebSocket", "Attempting to connect...")
        guard let url = URL(string: "\(Constants.wsURL)?token=\(token)") else {
            connectionError = "Invalid WebSocket URL"
            logError("WebSocket", "Invalid URL")
            isConnecting = false
            return
        }

        logDebug("WebSocket", "URL: \(url.absoluteString)")
        let request = URLRequest(url: url)
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session?.webSocketTask(with: request)

        webSocketTask?.resume()
    }

    /// 确认强制登录（顶替旧设备）
    func confirmForceLogin() {
        logInfo("WebSocket", "Sending force_login confirmation")
        let forceLogin: [String: String] = ["type": "force_login"]
        do {
            let data = try JSONSerialization.data(withJSONObject: forceLogin)
            let wsMessage = URLSessionWebSocketTask.Message.data(data)
            webSocketTask?.send(wsMessage) { error in
                if let error = error {
                    logError("WebSocket", "Failed to send force_login: \(error)")
                } else {
                    logInfo("WebSocket", "force_login sent successfully")
                }
            }
        } catch {
            logError("WebSocket", "Encoding error: \(error)")
        }
    }

    /// 取消登录（用户选择不顶替）
    func cancelLogin() {
        logInfo("WebSocket", "User cancelled login")
        shouldReconnect = false
        disconnect()
    }

    /// 断开连接
    func disconnect() {
        logInfo("WebSocket", "Disconnecting...")
        shouldReconnect = false
        isConnecting = false
        stopHeartbeat()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        session = nil  // 清除 session
        isConnected = false
        onMessageReceived = nil  // 清除回调
    }

    /// 发送心跳
    func sendHeartbeat() {
        guard let webSocketTask = webSocketTask else { return }

        let heartbeat: [String: String] = ["type": "heartbeat"]
        do {
            let data = try JSONSerialization.data(withJSONObject: heartbeat)
            let wsMessage = URLSessionWebSocketTask.Message.data(data)
            webSocketTask.send(wsMessage) { error in
                if let error = error {
                    logError("WebSocket", "send heartbeat error: \(error)")
                }
            }
        } catch {
            logError("WebSocket", "encoding error: \(error)")
        }
    }

    // MARK: - Private Methods

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage() // 继续接收下一条消息

            case .failure(let error):
                // 检查是否是正常关闭
                if !self.isConnected {
                    logInfo("WebSocket", "Socket already closed, stopping receive loop")
                    return
                }
                logError("WebSocket", "receive error: \(error.localizedDescription)")
                // 不在这里触发重连，让 delegate 处理
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            parseMessage(data)
        case .string(let string):
            if let data = string.data(using: .utf8) {
                parseMessage(data)
            }
        @unknown default:
            break
        }
    }

    private func parseMessage(_ data: Data) {
        // 打印收到的原始消息
        if let jsonString = String(data: data, encoding: .utf8) {
            logDebug("WebSocket", "received: \(jsonString)")
        }

        // 尝试解析简单消息（kicked, already_online, login_success 等）
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let type = json["type"] as? String {
                if type == "kicked" {
                    logWarn("WebSocket", "Received kicked message - another login detected")
                    shouldReconnect = false  // 不要自动重连
                    Task { @MainActor in
                        self.onKicked?()
                    }
                    return
                } else if type == "already_online" {
                    logInfo("WebSocket", "Already online detected - waiting for user confirmation")
                    isConnecting = false  // 不再连接中，等待确认
                    Task { @MainActor in
                        self.onAlreadyOnline?()
                    }
                    return
                } else if type == "login_success" {
                    logInfo("WebSocket", "Login success (force login confirmed)")
                    Task { @MainActor in
                        self.isConnected = true
                        self.connectionError = nil
                    }
                    return
                } else if type == "pong" {
                    logDebug("WebSocket", "received pong")
                    return
                } else if type == "auth_success" {
                    logInfo("WebSocket", "auth success")
                    return
                }
            }
        }

        // 尝试解析为服务端消息格式
        if let wsMessage = try? JSONDecoder().decode(WSReceivedMessage.self, from: data) {
            logDebug("WebSocket", "Parsed message type: \(wsMessage.type)")
            if wsMessage.type == "new_message" {
                if let message = wsMessage.toMessage() {
                    logInfo("WebSocket", "Successfully converted to Message, calling callback")
                    Task { @MainActor in
                        self.onMessageReceived?(message)
                    }
                } else {
                    logWarn("WebSocket", "toMessage() returned nil")
                }
            } else if wsMessage.type == "member_left" {
                // 成员离开事件
                if let conversationId = wsMessage.conversationId,
                   let userId = wsMessage.senderId,
                   let userName = wsMessage.senderName ?? wsMessage.content {
                    logInfo("WebSocket", "Member left: \(userName) from conversation \(conversationId)")
                    // 提取系统消息数据
                    var sysMsg: (id: String, content: String, createdAt: Date)? = nil
                    if let systemMessage = wsMessage.systemMessage {
                        sysMsg = (id: systemMessage.id, content: systemMessage.content, createdAt: systemMessage.createdAt)
                    }
                    Task { @MainActor in
                        self.onMemberLeft?(conversationId, userId, userName, sysMsg, wsMessage.newOwnerId, wsMessage.newOwnerName)
                    }
                }
            } else if wsMessage.type == "member_joined" {
                // 新成员加入事件
                if let conversationId = wsMessage.conversationId,
                   let userId = wsMessage.userId,
                   let userName = wsMessage.userName {
                    logInfo("WebSocket", "Member joined: \(userName) to conversation \(conversationId)")
                    // 提取系统消息数据
                    var sysMsg: (id: String, content: String, createdAt: Date)? = nil
                    if let systemMessage = wsMessage.systemMessage {
                        sysMsg = (id: systemMessage.id, content: systemMessage.content, createdAt: systemMessage.createdAt)
                    }
                    Task { @MainActor in
                        self.onMemberJoined?(conversationId, userId, userName, sysMsg)
                    }
                }
            } else if wsMessage.type == "group_invitation" {
                // 收到群邀请（等待管理员审批）
                let invitation = GroupInvitation(
                    id: wsMessage.id ?? "",
                    conversationId: wsMessage.conversationId,
                    conversationName: wsMessage.conversationName ?? wsMessage.content,
                    inviterId: wsMessage.inviterId ?? wsMessage.senderId,
                    inviteeId: wsMessage.inviteeId,
                    status: InvitationStatus(rawValue: wsMessage.status ?? "pending") ?? .pending,
                    createdAt: Date(),
                    inviter: nil,
                    invitee: nil
                )
                logInfo("WebSocket", "Received group invitation: \(invitation.id) for conversation: \(invitation.conversationName ?? "unknown")")
                Task { @MainActor in
                    self.onGroupInvitation?(invitation)
                }
            } else if wsMessage.type == "group_joined" {
                // 被管理员邀请直接加入群聊
                if let conversationId = wsMessage.conversationId,
                   let conversationName = wsMessage.conversationName ?? wsMessage.senderName ?? wsMessage.content {
                    logInfo("WebSocket", "Joined group: \(conversationName)")
                    Task { @MainActor in
                        self.onGroupJoined?(conversationId, conversationName)
                    }
                }
            } else if wsMessage.type == "group_invitation_approved" {
                // 群邀请被管理员批准
                if let conversationId = wsMessage.conversationId,
                   let invitationId = wsMessage.id {
                    logInfo("WebSocket", "Group invitation approved: \(invitationId)")
                    Task { @MainActor in
                        self.onGroupInvitationApproved?(invitationId, conversationId)
                    }
                }
            } else if wsMessage.type == "group_dissolved" {
                // 群聊解散
                if let conversationId = wsMessage.conversationId {
                    let conversationName = wsMessage.conversationName ?? "群聊"
                    logInfo("WebSocket", "Group dissolved: \(conversationName)")
                    Task { @MainActor in
                        self.onGroupDissolved?(conversationId, conversationName)
                    }
                }
            } else if wsMessage.type == "invite_request_updated" {
                // 邀请请求状态更新（审批后）
                if let conversationId = wsMessage.conversationId,
                   let invitationId = wsMessage.invitationId,
                   let status = wsMessage.status {
                    logInfo("WebSocket", "Invite request updated: \(invitationId) status: \(status)")
                    Task { @MainActor in
                        self.onInviteRequestUpdated?(conversationId, invitationId, status, wsMessage.approvedBy)
                    }
                }
            } else if wsMessage.type == "pong" {
                logDebug("WebSocket", "received pong")
            } else if wsMessage.type == "auth_success" {
                logInfo("WebSocket", "auth success")
            }
            return
        }
    }

    private func handleDisconnection() {
        guard shouldReconnect else {
            logInfo("WebSocket", "shouldReconnect is false, not reconnecting")
            return
        }

        isConnected = false

        // 尝试重连
        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            let delay = Constants.wsReconnectDelay * Double(reconnectAttempts)

            logInfo("WebSocket", "Scheduling reconnection attempt \(reconnectAttempts) in \(delay) seconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.shouldReconnect else { return }
                if let token = KeychainHelper.shared.get(forKey: Constants.StorageKeys.accessToken) {
                    self.connect(token: token)
                }
            }
        } else {
            connectionError = "WebSocket connection lost. Please refresh."
        }
    }

    private func startHeartbeat() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }

    private func stopHeartbeat() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketService: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.isConnected = true
            self.isConnecting = false
            self.connectionError = nil
            logInfo("WebSocket", "connected")

            // 开始接收消息
            self.receiveMessage()

            // 启动心跳
            self.startHeartbeat()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.isConnected = false
            self.isConnecting = false
            logInfo("WebSocket", "disconnected")

            // 只在应该重连时才尝试重连
            if self.shouldReconnect {
                self.handleDisconnection()
            }
        }
    }
}