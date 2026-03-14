//
//  FriendshipViewModel.swift
//  openAIM
//
//  Created by Claude on 2026/3/8.
//

import Foundation
import SwiftUI

/// 好友视图模型
@MainActor
@Observable
class FriendshipViewModel {
    // MARK: - 状态

    var friends: [Friendship] = []
    var friendRequests: [Friendship] = []
    var historyRequests: [Friendship] = []  // 历史请求（已接受/已拒绝）
    var searchResults: [SearchUser] = []
    var pendingRequestsCount: Int = 0

    var selectedFriend: Friendship?
    var selectedUser: SearchUser?

    var isLoading = false
    var isLoadingHistory = false  // 加载历史请求的状态
    var isSearching = false
    var errorMessage: String?

    // MARK: - 在线状态缓存

    var onlineStatus: [String: Bool] = [:]  // userId -> isOnline

    // MARK: - 搜索状态

    var searchQuery = ""
    var searchTotal = 0
    var searchPage = 1

    // MARK: - Private

    private let service = FriendshipService.shared

    // MARK: - 清除数据

    /// 清除所有数据（用于切换用户时）
    func clearData() {
        friends = []
        friendRequests = []
        historyRequests = []
        searchResults = []
        pendingRequestsCount = 0
        selectedFriend = nil
        selectedUser = nil
        errorMessage = nil
        onlineStatus = [:]
        clearSearch()
    }

    // MARK: - 好友列表

    func loadFriends() async {
        isLoading = true
        errorMessage = nil

        print("[DEBUG] Loading friends list...")

        do {
            let response = try await service.getFriends()
            print("[DEBUG] Friends response - total: \(response.total), items: \(response.items.count)")
            for friend in response.items {
                print("[DEBUG] Friendship ID: \(friend.id), user: \(friend.user?.name ?? "nil"), userID: \(friend.user?.id ?? "nil")")
            }
            friends = response.items
        } catch {
            print("[DEBUG] Failed to load friends: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 好友请求

    func loadFriendRequests() async {
        isLoading = true
        errorMessage = nil

        print("[DEBUG] Loading friend requests...")

        do {
            let response = try await service.getFriendRequests()
            print("[DEBUG] Friend requests response - total: \(response.total), items: \(response.items.count)")
            for item in response.items {
                print("[DEBUG] Request from: \(item.requester?.name ?? item.requester?.email ?? "unknown"), status: \(item.status)")
            }
            friendRequests = response.items
        } catch {
            print("[DEBUG] Failed to load friend requests: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadPendingRequestsCount() async {
        do {
            pendingRequestsCount = try await service.getPendingRequestsCount()
            print("[DEBUG] Pending requests count: \(pendingRequestsCount)")
        } catch {
            print("[DEBUG] Failed to load pending requests count: \(error)")
            // 静默失败
        }
    }

    func acceptRequest(_ request: Friendship) async {
        print("[DEBUG] Accepting friend request: \(request.id)")
        do {
            let updated = try await service.acceptFriendRequest(id: request.id)
            print("[DEBUG] Accept success, updated friendship: \(updated.id)")
            // 从请求列表移除
            friendRequests.removeAll { $0.id == request.id }
            // 更新计数
            pendingRequestsCount = max(0, pendingRequestsCount - 1)
            // 重新加载好友列表
            await loadFriends()
        } catch {
            print("[DEBUG] Failed to accept request: \(error)")
            // 如果请求已处理，刷新列表
            if error.localizedDescription.contains("已处理") {
                await loadFriendRequests()
                await loadPendingRequestsCount()
            }
            errorMessage = error.localizedDescription
        }
    }

    func rejectRequest(_ request: Friendship) async {
        print("[DEBUG] Rejecting friend request: \(request.id)")
        do {
            try await service.rejectFriendRequest(id: request.id)
            print("[DEBUG] Reject success")
            friendRequests.removeAll { $0.id == request.id }
            pendingRequestsCount = max(0, pendingRequestsCount - 1)
        } catch {
            print("[DEBUG] Failed to reject request: \(error)")
            // 如果请求已处理，刷新列表
            if error.localizedDescription.contains("已处理") {
                await loadFriendRequests()
                await loadPendingRequestsCount()
            }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 搜索用户

    func searchUsers(query: String? = nil) async {
        let searchTerm = query ?? searchQuery
        guard !searchTerm.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        errorMessage = nil

        print("[DEBUG] Searching for: \(searchTerm)")

        do {
            let response = try await service.searchUsers(query: searchTerm, page: searchPage)
            print("[DEBUG] Search response - total: \(response.total), items: \(response.items.count)")
            for item in response.items {
                print("[DEBUG] Found user: \(item.email), name: \(item.name ?? "nil")")
            }
            searchResults = response.items
            searchTotal = response.total
        } catch {
            print("[DEBUG] Search error: \(error)")
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchTotal = 0
        searchPage = 1
    }

    // MARK: - 发送好友请求

    func sendFriendRequest(to user: SearchUser) async {
        do {
            _ = try await service.sendFriendRequest(userId: user.id)
            // 更新搜索结果中的状态
            if let index = searchResults.firstIndex(where: { $0.id == user.id }) {
                searchResults[index].friendshipStatus = .pendingSent
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 删除好友

    func deleteFriend(_ friend: Friendship) async {
        do {
            try await service.deleteFriend(id: friend.id)
            friends.removeAll { $0.id == friend.id }
            if selectedFriend?.id == friend.id {
                selectedFriend = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 选择操作

    func selectFriend(_ friend: Friendship) {
        selectedFriend = friend
        selectedUser = nil
    }

    func selectUser(_ user: SearchUser) {
        selectedUser = user
        selectedFriend = nil
    }

    // MARK: - 刷新所有数据

    func refreshAll() async {
        async let friends = loadFriends()
        async let requests = loadFriendRequests()
        async let count = loadPendingRequestsCount()

        _ = await friends
        _ = await requests
        _ = await count
    }

    // MARK: - 在线状态

    /// 获取用户在线状态
    func fetchOnlineStatus(userIds: [String]) async {
        guard !userIds.isEmpty else { return }
        do {
            let statuses = try await service.getUsersOnlineStatus(userIds: userIds)
            onlineStatus.merge(statuses) { (_, new) in new }
        } catch {
            logWarn("FriendshipViewModel", "Failed to fetch online status: \(error)")
        }
    }

    /// 检查用户是否在线
    func isUserOnline(_ userId: String) -> Bool {
        return onlineStatus[userId] ?? false
    }

    /// 刷新好友在线状态
    func refreshFriendsOnlineStatus() async {
        let userIds = friends.compactMap { $0.user?.id }
        await fetchOnlineStatus(userIds: userIds)
    }

    // MARK: - 历史请求

    /// 加载历史好友请求（已接受和已拒绝的）
    func loadHistoryRequests() async {
        isLoadingHistory = true
        errorMessage = nil

        print("[DEBUG] Loading history friend requests...")

        do {
            // 获取已接受的请求
            let acceptedResponse = try await service.getFriendRequests(status: .accepted)
            // 获取已拒绝的请求
            let rejectedResponse = try await service.getFriendRequests(status: .rejected)

            // 合并两个列表
            var allHistory = acceptedResponse.items
            allHistory.append(contentsOf: rejectedResponse.items)

            // 按创建时间排序（最新的在前）
            allHistory.sort { $0.createdAt > $1.createdAt }

            historyRequests = allHistory
            print("[DEBUG] History requests loaded: \(historyRequests.count)")
        } catch {
            print("[DEBUG] Failed to load history requests: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoadingHistory = false
    }
}