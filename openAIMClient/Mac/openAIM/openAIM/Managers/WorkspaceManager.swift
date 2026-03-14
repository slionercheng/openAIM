//
//  WorkspaceManager.swift
//  openAIM
//
//  Created by Claude on 2026/3/14.
//

import Foundation

/// 用户工作区 - 管理单个用户的所有数据
struct UserWorkspace {
    let userId: String
    let email: String
    let workspaceURL: URL

    // 工作区内的文件路径
    var conversationsFile: URL { workspaceURL.appendingPathComponent("conversations.json") }
    var messagesDirectory: URL { workspaceURL.appendingPathComponent("messages") }
    var friendsFile: URL { workspaceURL.appendingPathComponent("friends.json") }
    var settingsFile: URL { workspaceURL.appendingPathComponent("settings.json") }
    var cacheDirectory: URL { workspaceURL.appendingPathComponent("cache") }
    var unreadCountsFile: URL { workspaceURL.appendingPathComponent("unread_counts.json") }

    /// 初始化工作区（创建目录结构）
    func initialize() {
        try? FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: messagesDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

/// 工作区管理器 - 支持多用户数据隔离
/// 每个用户的数据存储在独立的工作区目录中
@MainActor
@Observable
class WorkspaceManager {
    static let shared = WorkspaceManager()

    // MARK: - 当前工作区

    /// 当前活动的工作区（实例独享）
    private(set) var currentWorkspace: UserWorkspace?

    /// 工作区根目录
    private let workspacesRoot: URL

    private init() {
        // 工作区根目录: ~/Library/Application Support/OpenAIM/workspaces/
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        workspacesRoot = appSupport.appendingPathComponent("OpenAIM").appendingPathComponent("workspaces")

        // 确保根目录存在
        try? FileManager.default.createDirectory(at: workspacesRoot, withIntermediateDirectories: true)
    }

    // MARK: - 工作区管理

    /// 切换到指定用户的工作区
    func switchToWorkspace(userId: String, email: String) -> UserWorkspace {
        // 工作区目录: ~/Library/Application Support/OpenAIM/workspaces/{userId}/
        let workspaceURL = workspacesRoot.appendingPathComponent(userId)
        let workspace = UserWorkspace(userId: userId, email: email, workspaceURL: workspaceURL)

        // 初始化工作区目录
        workspace.initialize()

        currentWorkspace = workspace
        logInfo("WorkspaceManager", "Switched to workspace for user: \(email)")

        return workspace
    }

    /// 清除当前工作区
    func clearWorkspace() {
        currentWorkspace = nil
        logInfo("WorkspaceManager", "Workspace cleared")
    }

    // MARK: - 数据持久化

    /// 保存会话列表到工作区
    func saveConversations(_ conversations: [Conversation]) {
        guard let workspace = currentWorkspace else { return }

        do {
            let data = try JSONEncoder().encode(conversations)
            try data.write(to: workspace.conversationsFile)
            logDebug("WorkspaceManager", "Saved \(conversations.count) conversations")
        } catch {
            logError("WorkspaceManager", "Failed to save conversations: \(error)")
        }
    }

    /// 从工作区加载会话列表
    func loadConversations() -> [Conversation] {
        guard let workspace = currentWorkspace else { return [] }

        do {
            let data = try Data(contentsOf: workspace.conversationsFile)
            let conversations = try JSONDecoder().decode([Conversation].self, from: data)
            logDebug("WorkspaceManager", "Loaded \(conversations.count) conversations")
            return conversations
        } catch {
            // 文件不存在或解析失败，返回空数组
            return []
        }
    }

    /// 保存消息到工作区
    func saveMessages(conversationId: String, messages: [Message]) {
        guard let workspace = currentWorkspace else { return }

        do {
            let data = try JSONEncoder().encode(messages)
            let fileURL = workspace.messagesDirectory.appendingPathComponent("\(conversationId).json")
            try data.write(to: fileURL)
            logDebug("WorkspaceManager", "Saved \(messages.count) messages for conversation: \(conversationId)")
        } catch {
            logError("WorkspaceManager", "Failed to save messages: \(error)")
        }
    }

    /// 从工作区加载消息
    func loadMessages(conversationId: String) -> [Message] {
        guard let workspace = currentWorkspace else { return [] }

        do {
            let fileURL = workspace.messagesDirectory.appendingPathComponent("\(conversationId).json")
            let data = try Data(contentsOf: fileURL)
            let messages = try JSONDecoder().decode([Message].self, from: data)
            return messages
        } catch {
            return []
        }
    }

    /// 保存好友列表到工作区
    func saveFriends(_ friends: [Friendship]) {
        guard let workspace = currentWorkspace else { return }

        do {
            let data = try JSONEncoder().encode(friends)
            try data.write(to: workspace.friendsFile)
            logDebug("WorkspaceManager", "Saved \(friends.count) friends")
        } catch {
            logError("WorkspaceManager", "Failed to save friends: \(error)")
        }
    }

    /// 从工作区加载好友列表
    func loadFriends() -> [Friendship] {
        guard let workspace = currentWorkspace else { return [] }

        do {
            let data = try Data(contentsOf: workspace.friendsFile)
            let friends = try JSONDecoder().decode([Friendship].self, from: data)
            return friends
        } catch {
            return []
        }
    }

    /// 保存用户设置
    func saveSettings(_ settings: UserSettings) {
        guard let workspace = currentWorkspace else { return }

        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: workspace.settingsFile)
        } catch {
            logError("WorkspaceManager", "Failed to save settings: \(error)")
        }
    }

    /// 加载用户设置
    func loadSettings() -> UserSettings {
        guard let workspace = currentWorkspace else { return UserSettings() }

        do {
            let data = try Data(contentsOf: workspace.settingsFile)
            return try JSONDecoder().decode(UserSettings.self, from: data)
        } catch {
            return UserSettings()
        }
    }

    // MARK: - 工作区列表

    /// 获取所有工作区（用于账号选择）
    func getAllWorkspaces() -> [(userId: String, email: String)] {
        do {
            let directories = try FileManager.default.contentsOfDirectory(at: workspacesRoot, includingPropertiesForKeys: nil)
            return directories.compactMap { url -> (String, String)? in
                let userId = url.lastPathComponent
                // 尝试读取该工作区的设置获取邮箱
                let settingsFile = url.appendingPathComponent("settings.json")
                if let data = try? Data(contentsOf: settingsFile),
                   let settings = try? JSONDecoder().decode(UserSettings.self, from: data) {
                    return (userId, settings.email)
                }
                return nil
            }
        } catch {
            return []
        }
    }

    /// 删除工作区
    func deleteWorkspace(userId: String) {
        let workspaceURL = workspacesRoot.appendingPathComponent(userId)
        try? FileManager.default.removeItem(at: workspaceURL)
        logInfo("WorkspaceManager", "Deleted workspace for user: \(userId)")
    }

    /// 保存未读消息数
    func saveUnreadCounts(_ counts: [String: Int]) {
        guard let workspace = currentWorkspace else { return }

        do {
            let data = try JSONEncoder().encode(counts)
            try data.write(to: workspace.unreadCountsFile)
            logDebug("WorkspaceManager", "Saved unread counts for \(counts.count) conversations")
        } catch {
            logError("WorkspaceManager", "Failed to save unread counts: \(error)")
        }
    }

    /// 加载未读消息数
    func loadUnreadCounts() -> [String: Int] {
        guard let workspace = currentWorkspace else { return [:] }

        do {
            let data = try Data(contentsOf: workspace.unreadCountsFile)
            let counts = try JSONDecoder().decode([String: Int].self, from: data)
            logDebug("WorkspaceManager", "Loaded unread counts for \(counts.count) conversations")
            return counts
        } catch {
            return [:]
        }
    }
}

// MARK: - 用户设置

struct UserSettings: Codable {
    var email: String = ""
    var notifications: Bool = true
    var theme: String = "system"
    var fontSize: Int = 14
}