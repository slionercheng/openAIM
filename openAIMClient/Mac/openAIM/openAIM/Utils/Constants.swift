//
//  Constants.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation

/// 应用常量
struct Constants {
    // MARK: - API
    static let baseURL = "http://localhost:8080/api/v1"
    static let wsURL = "ws://localhost:8080/ws"
    
    // MARK: - API Endpoints
    struct Auth {
        static let login = "/auth/login"
        static let register = "/auth/register"
        static let logout = "/auth/logout"
        static let refresh = "/auth/refresh"
    }
    
    struct Users {
        static let me = "/users/me"
        static let myOrgs = "/users/me/orgs"
        static let myAgents = "/users/me/agents"
        static let onlineStatus = "/users/online-status"

        static func userOnline(_ id: String) -> String { "/users/\(id)/online" }
    }
    
    struct Agents {
        static let base = "/agents"
        static func detail(_ id: String) -> String { "/agents/\(id)" }
        static func joinRequests(_ id: String) -> String { "/agents/\(id)/join-requests" }
        static func regenerateToken(_ id: String) -> String { "/agents/\(id)/regenerate-token" }
    }
    
    struct Organizations {
        static let base = "/organizations"
        static func detail(_ id: String) -> String { "/organizations/\(id)" }
        static func members(_ id: String) -> String { "/organizations/\(id)/members" }
        static func invitations(_ id: String) -> String { "/organizations/\(id)/invitations" }
        static func agents(_ id: String) -> String { "/organizations/\(id)/agents" }
    }
    
    struct Conversations {
        static let base = "/conversations"
        static let search = "/conversations/search"
        static let myInvitations = "/conversations/invitations"  // 用户收到的群邀请
        static func detail(_ id: String) -> String { "/conversations/\(id)" }
        static func messages(_ id: String) -> String { "/conversations/\(id)/messages" }
        static func participants(_ id: String) -> String { "/conversations/\(id)/participants" }
        static func settings(_ id: String) -> String { "/conversations/\(id)/settings" }
        static func joinRequests(_ id: String) -> String { "/conversations/\(id)/join-requests" }
        static func invite(_ id: String) -> String { "/conversations/\(id)/invite" }
        static func invitations(_ id: String) -> String { "/conversations/\(id)/invitations" }
        static func handleInvitation(_ id: String, action: String) -> String { "/conversations/invitations/\(id)/\(action)" }
    }
    
    struct JoinRequests {
        static let base = "/join-requests"
        static func approve(_ id: String) -> String { "/join-requests/\(id)/approve" }
        static func reject(_ id: String) -> String { "/join-requests/\(id)/reject" }
    }

    struct Friends {
        static let base = "/friends"
        static let search = "/users/search"
        static let requests = "/friends/requests"
        static let requestsCount = "/friends/requests/count"
        static let sendRequest = "/friends/request"

        static func acceptRequest(_ id: String) -> String { "/friends/requests/\(id)/accept" }
        static func rejectRequest(_ id: String) -> String { "/friends/requests/\(id)/reject" }
        static func delete(_ id: String) -> String { "/friends/\(id)" }
    }

    // MARK: - Storage Keys
    struct StorageKeys {
        static let accessToken = "openaim_access_token"
        static let refreshToken = "openaim_refresh_token"
        static let currentUser = "openaim_current_user"
    }
    
    // MARK: - Timeouts
    static let requestTimeout: TimeInterval = 30
    static let wsReconnectDelay: TimeInterval = 3
}