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
}

/// WebSocket 消息
struct WSMessage: Codable {
    let type: WSMessageType
    let data: [String: String]?
    
    init(type: WSMessageType, data: [String: String]? = nil) {
        self.type = type
        self.data = data
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
    private var timer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    
    // MARK: - Callbacks
    
    var onMessageReceived: ((Message) -> Void)?
    var onUserOnline: ((String) -> Void)?
    var onUserOffline: ((String) -> Void)?
    var onTyping: ((String, Bool) -> Void)?
    
    // MARK: - Private Properties
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// 连接 WebSocket
    func connect(token: String) {
        guard let url = URL(string: "\(Constants.wsURL)?token=\(token)") else {
            connectionError = "Invalid WebSocket URL"
            return
        }
        
        let request = URLRequest(url: url)
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: request)
        
        webSocketTask?.resume()
        
        // 开始接收消息
        receiveMessage()
        
        // 启动心跳
        startHeartbeat()
        
        reconnectAttempts = 0
    }
    
    /// 断开连接
    func disconnect() {
        stopHeartbeat()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
    
    /// 发送消息
    func send(type: WSMessageType, data: [String: String]? = nil) {
        guard let webSocketTask = webSocketTask else { return }
        
        let message = WSMessage(type: type, data: data)
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(message)
            let wsMessage = URLSessionWebSocketTask.Message.data(data)
            webSocketTask.send(wsMessage) { error in
                if let error = error {
                    print("WebSocket send error: \(error)")
                }
            }
        } catch {
            print("WebSocket encoding error: \(error)")
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
                print("WebSocket receive error: \(error)")
                self.handleDisconnection()
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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // 尝试解析为消息
        if let message = try? decoder.decode(Message.self, from: data) {
            onMessageReceived?(message)
            return
        }
        
        // 尝试解析为 WebSocket 消息
        if let wsMessage = try? decoder.decode(WSMessage.self, from: data) {
            handleWSMessage(wsMessage)
        }
    }
    
    private func handleWSMessage(_ message: WSMessage) {
        switch message.type {
        case .newMessage:
            // 新消息已在上层处理
            break
        case .ping:
            send(type: .pong)
        case .pong:
            break
        case .userOnline:
            if let userId = message.data?["userId"] {
                onUserOnline?(userId)
            }
        case .userOffline:
            if let userId = message.data?["userId"] {
                onUserOffline?(userId)
            }
        case .typing:
            break
        case .messageRead:
            break
        }
    }
    
    private func handleDisconnection() {
        isConnected = false
        
        // 尝试重连
        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            let delay = Constants.wsReconnectDelay * Double(reconnectAttempts)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
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
            self?.send(type: .ping)
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
            self?.isConnected = true
            self?.connectionError = nil
            print("WebSocket connected")
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task { @MainActor [weak self] in
            self?.isConnected = false
            print("WebSocket disconnected")
        }
    }
}