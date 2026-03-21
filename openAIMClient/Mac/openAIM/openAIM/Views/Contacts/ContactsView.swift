//
//  ContactsView.swift
//  openAIM
//
//  Created by Claude on 2026/3/8.
//

import SwiftUI

struct ContactsView: View {
    @Environment(AppViewModel.self) private var appViewModel

    @State private var selectedTab: ContactsTab = .friends
    @State private var showSearchView = false
    @State private var searchQuery = ""
    @State private var localSearchQuery = ""  // 本地好友搜索
    @FocusState private var isSearchFocused: Bool

    enum ContactsTab {
        case friends
        case requests
        case history
    }

    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            contactsSidebar

            // 主区域 - 背景浅灰色 #F1F5F9
            if let friend = appViewModel.friendshipViewModel.selectedFriend {
                FriendDetailView(friend: friend)
            } else if let user = appViewModel.friendshipViewModel.selectedUser {
                SearchUserDetailView(user: user)
            } else if let invitation = appViewModel.friendshipViewModel.selectedGroupInvitation {
                GroupInvitationDetailView(invitation: invitation)
            } else {
                emptyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.945, green: 0.961, blue: 0.969)) // #F1F5F9 主背景
    }

    // MARK: - Contacts Sidebar

    private var contactsSidebar: some View {
        VStack(spacing: 0) {
            if showSearchView {
                // 搜索模式 Header
                HStack(spacing: 12) {
                    // 返回按钮: 28x28, 圆角6px, 背景#F1F5F9
                    Button {
                        showSearchView = false
                        appViewModel.friendshipViewModel.clearSearch()
                        searchQuery = ""
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: 0.945, green: 0.961, blue: 0.969)) // #F1F5F9
                                .frame(width: 28, height: 28)

                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231)) // #1E293B
                        }
                    }
                    .buttonStyle(.plain)

                    Text("Add Friend")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231)) // #1E293B

                    Spacer()
                }
                .frame(height: 64)
                .padding(.horizontal, 16)
                .overlay(
                    Rectangle()
                        .fill(Color(red: 0.886, green: 0.910, blue: 0.941)) // #E2E8F0
                        .frame(height: 1),
                    alignment: .bottom
                )

                // 搜索区域
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // 搜索输入框: 高度40px, 圆角8px, 背景#F1F5F9
                        HStack(spacing: 0) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722)) // #94A3B8

                            ZStack(alignment: .leading) {
                                if searchQuery.isEmpty {
                                    Text("Search by email or name...")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722)) // #94A3B8
                                }

                                TextField("", text: $searchQuery)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231)) // #1E293B
                                    .onSubmit {
                                        performSearch()
                                    }
                                    .focused($isSearchFocused)
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.945, green: 0.961, blue: 0.969)) // #F1F5F9
                        )

                        // 搜索按钮: 高度40px, 背景#3B82F6
                        Button {
                            performSearch()
                        } label: {
                            Text("Search")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(height: 40)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.231, green: 0.510, blue: 0.965)) // #3B82F6
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(searchQuery.isEmpty)
                        .opacity(searchQuery.isEmpty ? 0.5 : 1)
                    }
                    .padding(16)

                    Divider()

                    // 搜索结果
                    searchResultsView
                }
            } else {
                // 正常模式 Header
                HStack {
                    Text("Contacts")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231)) // #1E293B

                    Spacer()

                    // 搜索按钮
                    Button {
                        showSearchView = true
                        appViewModel.friendshipViewModel.selectedFriend = nil
                        appViewModel.friendshipViewModel.selectedUser = nil
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.945, green: 0.961, blue: 0.969)) // #F1F5F9
                                .frame(width: 32, height: 32)

                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549)) // #64748B
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 64)
                .padding(.horizontal, 16)
                .overlay(
                    Rectangle()
                        .fill(Color(red: 0.886, green: 0.910, blue: 0.941)) // #E2E8F0
                        .frame(height: 1),
                    alignment: .bottom
                )

                // Tabs
                HStack(spacing: 8) {
                    Button {
                        selectedTab = .friends
                    } label: {
                        Text("Friends")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(selectedTab == .friends
                                ? Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
                                : Color(red: 0.392, green: 0.455, blue: 0.549)) // #64748B
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTab == .friends
                                        ? Color(red: 0.937, green: 0.965, blue: 1.0) // #EFF6FF
                                        : .white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.886, green: 0.910, blue: 0.941), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        selectedTab = .requests
                    } label: {
                        HStack(spacing: 6) {
                            Text("Requests")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selectedTab == .requests
                                    ? Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
                                    : Color(red: 0.392, green: 0.455, blue: 0.549)) // #64748B

                            if appViewModel.friendshipViewModel.totalPendingCount > 0 {
                                Text("\(appViewModel.friendshipViewModel.totalPendingCount)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(
                                        Circle()
                                            .fill(Color(red: 0.937, green: 0.267, blue: 0.267)) // #EF4444
                                    )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == .requests
                                    ? Color(red: 0.937, green: 0.965, blue: 1.0) // #EFF6FF
                                    : .white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.886, green: 0.910, blue: 0.941), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        selectedTab = .history
                        Task {
                            await appViewModel.friendshipViewModel.loadHistoryRequests()
                        }
                    } label: {
                        Text("History")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(selectedTab == .history
                                ? Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
                                : Color(red: 0.392, green: 0.455, blue: 0.549)) // #64748B
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTab == .history
                                        ? Color(red: 0.937, green: 0.965, blue: 1.0) // #EFF6FF
                                        : .white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.886, green: 0.910, blue: 0.941), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                // 列表内容
                if selectedTab == .friends {
                    friendsListView
                } else if selectedTab == .requests {
                    requestsListView
                } else {
                    historyListView
                }
            }
        }
        .frame(width: 320)
        .background(.white)
        .overlay(
            Rectangle()
                .fill(Color(red: 0.886, green: 0.910, blue: 0.941)) // #E2E8F0
                .frame(width: 1),
            alignment: .trailing
        )
        .onAppear {
            if showSearchView {
                isSearchFocused = true
            }
        }
        .onChange(of: showSearchView) { _, newValue in
            if newValue {
                isSearchFocused = true
            }
        }
    }

    // MARK: - Search Results View

    private var searchResultsView: some View {
        Group {
            if appViewModel.friendshipViewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appViewModel.friendshipViewModel.searchResults.isEmpty {
                if searchQuery.isEmpty {
                    VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))

                    Text("Search for users by email or name")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))

                        Text("No users found")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))

                        Text("Try a different search term")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Results Header
                        HStack {
                            Text("Results")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549)) // #64748B

                            Spacer()

                            Text("\(appViewModel.friendshipViewModel.searchTotal) found")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722)) // #94A3B8
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                        // Results List
                        LazyVStack(spacing: 4) {
                            ForEach(appViewModel.friendshipViewModel.searchResults) { user in
                                SearchUserRowView(user: user)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Friends List

    private var friendsListView: some View {
        Group {
            if appViewModel.friendshipViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appViewModel.friendshipViewModel.friends.isEmpty {
                emptyFriendsView
            } else {
                VStack(spacing: 0) {
                    // 本地搜索框
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))

                        ZStack(alignment: .leading) {
                            if localSearchQuery.isEmpty {
                                Text("Search friends...")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))
                            }

                            TextField("", text: $localSearchQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.945, green: 0.961, blue: 0.969))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()

                    if filteredFriends.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))

                            Text("No friends match '\(localSearchQuery)'")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredFriends) { friendship in
                                    FriendRowView(
                                        friendship: friendship,
                                        isSelected: appViewModel.friendshipViewModel.selectedFriend?.id == friendship.id
                                    ) {
                                        appViewModel.friendshipViewModel.selectFriend(friendship)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }

    private var filteredFriends: [Friendship] {
        let allFriends = appViewModel.friendshipViewModel.friends
        guard !localSearchQuery.isEmpty else { return allFriends }

        let query = localSearchQuery.lowercased()
        return allFriends.filter { friendship in
            if let name = friendship.user?.name, name.lowercased().contains(query) { return true }
            if let email = friendship.user?.email, email.lowercased().contains(query) { return true }
            return false
        }
    }

    private var emptyFriendsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))

            Text("No friends yet")
                .font(.system(size: 15))
                .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))

            Button {
                showSearchView = true
            } label: {
                Text("Search Users")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Requests List

    private var requestsListView: some View {
        Group {
            if appViewModel.friendshipViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appViewModel.friendshipViewModel.friendRequests.isEmpty && appViewModel.friendshipViewModel.groupInvitations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))

                    Text("No pending requests")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        // 好友请求
                        if !appViewModel.friendshipViewModel.friendRequests.isEmpty {
                            SectionHeader(title: "Friend Requests", count: appViewModel.friendshipViewModel.friendRequests.count)

                            ForEach(appViewModel.friendshipViewModel.friendRequests) { request in
                                RequestRowView(
                                    request: request,
                                    onAccept: {
                                        Task {
                                            await appViewModel.friendshipViewModel.acceptRequest(request)
                                        }
                                    },
                                    onReject: {
                                        Task {
                                            await appViewModel.friendshipViewModel.rejectRequest(request)
                                        }
                                    }
                                )
                            }
                        }

                        // 群聊邀请
                        if !appViewModel.friendshipViewModel.groupInvitations.isEmpty {
                            SectionHeader(title: "Group Invitations", count: appViewModel.friendshipViewModel.groupInvitations.count)

                            ForEach(appViewModel.friendshipViewModel.groupInvitations) { invitation in
                                GroupInvitationRowView(
                                    invitation: invitation,
                                    isSelected: appViewModel.friendshipViewModel.selectedGroupInvitation?.id == invitation.id,
                                    onTap: {
                                        appViewModel.friendshipViewModel.selectGroupInvitation(invitation)
                                    },
                                    onAccept: {
                                        Task {
                                            await appViewModel.friendshipViewModel.acceptGroupInvitation(invitation)
                                        }
                                    },
                                    onReject: {
                                        Task {
                                            await appViewModel.friendshipViewModel.rejectGroupInvitation(invitation)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - History List

    private var historyListView: some View {
        Group {
            if appViewModel.friendshipViewModel.isLoadingHistory {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appViewModel.friendshipViewModel.historyRequests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))

                    Text("No history requests")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))

                    Text("Accepted and rejected requests will appear here")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appViewModel.friendshipViewModel.historyRequests) { request in
                            HistoryRequestRowView(request: request)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 64))
                .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))

            Text("Select a contact to view details")
                .font(.system(size: 16))
                .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
    }

    // MARK: - Actions

    private func performSearch() {
        guard !searchQuery.isEmpty else { return }

        Task {
            appViewModel.friendshipViewModel.searchQuery = searchQuery
            await appViewModel.friendshipViewModel.searchUsers()
        }
    }
}

// MARK: - Friend Row View

struct FriendRowView: View {
    let friendship: Friendship
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(avatarInitial)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(friendship.user?.name ?? friendship.user?.email ?? "Unknown")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                        .lineLimit(1)

                    Text(friendship.user?.email ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549)) // #64748B
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                        ? Color(red: 0.937, green: 0.965, blue: 1.0)
                        : .white)
            )
        }
        .buttonStyle(.plain)
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = (friendship.user?.name ?? friendship.user?.id ?? "").hashValue
        return colors[abs(hash) % colors.count]
    }

    private var avatarInitial: String {
        if let name = friendship.user?.name, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        } else if let email = friendship.user?.email, !email.isEmpty {
            return String(email.prefix(1)).uppercased()
        }
        return "?"
    }
}

// MARK: - Request Row View

struct RequestRowView: View {
    let request: Friendship
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(avatarColor)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(avatarInitial)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(request.requester?.name ?? request.requester?.email ?? "Unknown")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                    .lineLimit(1)

                Text("wants to be your friend")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549)) // #64748B
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    onAccept()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color(red: 0.133, green: 0.773, blue: 0.369))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onReject()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color(red: 0.937, green: 0.267, blue: 0.267))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.945, green: 0.961, blue: 0.969))
        )
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = (request.requester?.name ?? request.requester?.id ?? "").hashValue
        return colors[abs(hash) % colors.count]
    }

    private var avatarInitial: String {
        if let name = request.requester?.name, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        } else if let email = request.requester?.email, !email.isEmpty {
            return String(email.prefix(1)).uppercased()
        }
        return "?"
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))

            Text("(\(count))")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Group Invitation Row View

struct GroupInvitationRowView: View {
    let invitation: GroupInvitation
    let isSelected: Bool
    let onTap: () -> Void
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // 群聊图标
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(red: 0.231, green: 0.510, blue: 0.965))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(invitation.conversationName ?? "Group Chat")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                        .lineLimit(1)

                    Text(statusText)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                }

                Spacer()

                // 根据状态显示不同按钮
                if invitation.status == .pending {
                    // 管理员邀请，可以直接接受/拒绝
                    HStack(spacing: 8) {
                        Button {
                            onAccept()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color(red: 0.133, green: 0.773, blue: 0.369))
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            onReject()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color(red: 0.937, green: 0.267, blue: 0.267))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                } else if invitation.status == .pendingApproval {
                    // 普通成员邀请，等待管理员审批
                    Text("Waiting")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.949, green: 0.6, blue: 0.114))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(red: 0.949, green: 0.6, blue: 0.114).opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                        ? Color(red: 0.937, green: 0.965, blue: 1.0)
                        : Color(red: 0.945, green: 0.961, blue: 0.969))
            )
        }
        .buttonStyle(.plain)
    }

    private var statusText: String {
        if let inviterName = invitation.inviter?.name {
            return "Invited by \(inviterName)"
        }
        return "Group invitation"
    }
}

// MARK: - History Request Row View

struct HistoryRequestRowView: View {
    let request: Friendship

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(avatarColor)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(avatarInitial)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(request.requester?.name ?? request.requester?.email ?? "Unknown")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                    .lineLimit(1)

                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(statusColor)
            }

            Spacer()

            // 状态标签
            Text(statusLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusBackgroundColor)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
        )
    }

    private var statusText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: request.createdAt)
        return "\(statusLabel) · \(dateStr)"
    }

    private var statusLabel: String {
        guard let status = request.status else { return "Unknown" }
        switch status {
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        default: return "Unknown"
        }
    }

    private var statusColor: Color {
        guard let status = request.status else { return Color.gray }
        switch status {
        case .accepted: return Color(red: 0.133, green: 0.773, blue: 0.369)
        case .rejected: return Color(red: 0.937, green: 0.267, blue: 0.267)
        default: return Color.gray
        }
    }

    private var statusBackgroundColor: Color {
        guard let status = request.status else { return Color.gray }
        switch status {
        case .accepted: return Color(red: 0.133, green: 0.773, blue: 0.369)
        case .rejected: return Color(red: 0.937, green: 0.267, blue: 0.267)
        default: return Color.gray
        }
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = (request.requester?.name ?? request.requester?.id ?? "").hashValue
        return colors[abs(hash) % colors.count]
    }

    private var avatarInitial: String {
        if let name = request.requester?.name, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        } else if let email = request.requester?.email, !email.isEmpty {
            return String(email.prefix(1)).uppercased()
        }
        return "?"
    }
}

#Preview {
    ContactsView()
        .environment(AppViewModel())
}