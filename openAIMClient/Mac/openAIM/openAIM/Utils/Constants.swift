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
        static func detail(_ id: String) -> String { "/conversations/\(id)" }
        static func messages(_ id: String) -> String { "/conversations/\(id)/messages" }
        static func participants(_ id: String) -> String { "/conversations/\(id)/participants" }
    }
    
    struct JoinRequests {
        static let base = "/join-requests"
        static func approve(_ id: String) -> String { "/join-requests/\(id)/approve" }
        static func reject(_ id: String) -> String { "/join-requests/\(id)/reject" }
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