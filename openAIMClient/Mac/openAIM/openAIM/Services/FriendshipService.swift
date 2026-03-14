//
//  FriendshipService.swift
//  openAIM
//
//  Created by Claude on 2026/3/8.
//

import Foundation

/// 好友服务
actor FriendshipService {
    static let shared = FriendshipService()

    private let apiClient = APIClient.shared

    private init() {}

    // MARK: - 搜索用户

    /// 搜索用户
    func searchUsers(query: String, page: Int = 1, pageSize: Int = 20) async throws -> SearchUsersResponse {
        let queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        let response: SearchUsersResponse = try await apiClient.get(
            Constants.Friends.search,
            queryItems: queryItems
        )
        return response
    }

    // MARK: - 好友列表

    /// 获取好友列表
    func getFriends(page: Int = 1, pageSize: Int = 50) async throws -> FriendsListResponse {
        let queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        print("[DEBUG] Getting friends from: \(Constants.Friends.base)")
        let response: FriendsListResponse = try await apiClient.get(
            Constants.Friends.base,
            queryItems: queryItems
        )
        print("[DEBUG] Friends API response - total: \(response.total), items count: \(response.items.count)")
        return response
    }

    // MARK: - 好友请求

    /// 获取好友请求列表
    func getFriendRequests(status: FriendshipStatus = .pending, page: Int = 1) async throws -> FriendsListResponse {
        let queryItems = [
            URLQueryItem(name: "status", value: status.rawValue),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        print("[DEBUG] Getting friend requests from: \(Constants.Friends.requests)")
        let response: FriendsListResponse = try await apiClient.get(
            Constants.Friends.requests,
            queryItems: queryItems
        )
        print("[DEBUG] Friend requests API response - total: \(response.total), items count: \(response.items.count)")
        return response
    }

    /// 获取待处理好友请求数量
    func getPendingRequestsCount() async throws -> Int {
        let response: FriendRequestsCountResponse = try await apiClient.get(Constants.Friends.requestsCount)
        return response.count
    }

    /// 发送好友请求
    func sendFriendRequest(userId: String) async throws -> Friendship {
        let request = SendFriendRequest(userId: userId)
        let friendship: Friendship = try await apiClient.post(Constants.Friends.sendRequest, body: request)
        return friendship
    }

    /// 接受好友请求
    func acceptFriendRequest(id: String) async throws -> Friendship {
        let friendship: Friendship = try await apiClient.post(Constants.Friends.acceptRequest(id), body: Empty())
        return friendship
    }

    /// 拒绝好友请求
    func rejectFriendRequest(id: String) async throws {
        try await apiClient.post(Constants.Friends.rejectRequest(id), body: Empty())
    }

    // MARK: - 删除好友

    /// 删除好友
    func deleteFriend(id: String) async throws {
        try await apiClient.delete(Constants.Friends.delete(id))
    }

    // MARK: - 在线状态

    /// 获取单个用户在线状态
    func getUserOnlineStatus(userId: String) async throws -> Bool {
        let response: OnlineStatusResponse = try await apiClient.get(Constants.Users.userOnline(userId))
        return response.online
    }

    /// 批量获取用户在线状态
    func getUsersOnlineStatus(userIds: [String]) async throws -> [String: Bool] {
        let request = OnlineStatusRequest(userIds: userIds)
        let response: [String: Bool] = try await apiClient.post(Constants.Users.onlineStatus, body: request)
        return response
    }
}

/// 在线状态请求
struct OnlineStatusRequest: Codable {
    let userIds: [String]
}

/// 在线状态响应
struct OnlineStatusResponse: Codable {
    let userId: String
    let online: Bool
}