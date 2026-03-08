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
    var searchResults: [SearchUser] = []
    var pendingRequestsCount: Int = 0

    var selectedFriend: Friendship?
    var selectedUser: SearchUser?

    var isLoading = false
    var isSearching = false
    var errorMessage: String?

    // MARK: - 搜索状态

    var searchQuery = ""
    var searchTotal = 0
    var searchPage = 1

    // MARK: - Private

    private let service = FriendshipService.shared

    // MARK: - 好友列表

    func loadFriends() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await service.getFriends()
            friends = response.items
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 好友请求

    func loadFriendRequests() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await service.getFriendRequests()
            friendRequests = response.items
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadPendingRequestsCount() async {
        do {
            pendingRequestsCount = try await service.getPendingRequestsCount()
        } catch {
            // 静默失败
        }
    }

    func acceptRequest(_ request: Friendship) async {
        do {
            let updated = try await service.acceptFriendRequest(id: request.id)
            // 从请求列表移除
            friendRequests.removeAll { $0.id == request.id }
            // 添加到好友列表
            friends.insert(updated, at: 0)
            // 更新计数
            pendingRequestsCount = max(0, pendingRequestsCount - 1)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectRequest(_ request: Friendship) async {
        do {
            try await service.rejectFriendRequest(id: request.id)
            friendRequests.removeAll { $0.id == request.id }
            pendingRequestsCount = max(0, pendingRequestsCount - 1)
        } catch {
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

        do {
            let response = try await service.searchUsers(query: searchTerm, page: searchPage)
            searchResults = response.items
            searchTotal = response.total
        } catch {
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
}