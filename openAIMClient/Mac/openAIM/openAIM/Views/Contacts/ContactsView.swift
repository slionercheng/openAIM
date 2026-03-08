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
    @State private var showSearchSheet = false

    enum ContactsTab {
        case friends
        case requests
    }

    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            contactsSidebar

            // 主区域
            if let friend = appViewModel.friendshipViewModel.selectedFriend {
                FriendDetailView(friend: friend)
            } else if let user = appViewModel.friendshipViewModel.selectedUser {
                SearchUserDetailView(user: user)
            } else {
                emptyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showSearchSheet) {
            SearchUsersView()
        }
    }

    // MARK: - Contacts Sidebar

    private var contactsSidebar: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Text("Contacts")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Button {
                    showSearchSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(16)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )

            // Tab 切换
            HStack(spacing: 0) {
                Button {
                    selectedTab = .friends
                } label: {
                    Text("Friends")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == .friends ? Color.blue.opacity(0.1) : Color.clear)
                        .foregroundStyle(selectedTab == .friends ? .blue : .primary)
                }

                Button {
                    selectedTab = .requests
                } label: {
                    HStack(spacing: 6) {
                        Text("Requests")
                            .font(.system(size: 14, weight: .medium))

                        if appViewModel.friendshipViewModel.pendingRequestsCount > 0 {
                            Text("\(appViewModel.friendshipViewModel.pendingRequestsCount)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(100)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == .requests ? Color.blue.opacity(0.1) : Color.clear)
                    .foregroundStyle(selectedTab == .requests ? .blue : .primary)
                }
            }
            .background(Color.gray.opacity(0.05))

            Divider()

            // 列表内容
            if selectedTab == .friends {
                friendsListView
            } else {
                requestsListView
            }
        }
        .frame(width: 280)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1),
            alignment: .trailing
        )
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
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appViewModel.friendshipViewModel.friends) { friendship in
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

    private var emptyFriendsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No friends yet")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            Button {
                showSearchSheet = true
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
            } else if appViewModel.friendshipViewModel.friendRequests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("No pending requests")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
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
                .foregroundStyle(.secondary)

            Text("Select a contact to view details")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
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
                // 头像
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
                        .lineLimit(1)

                    Text(friendship.user?.email ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
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
            // 头像
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
                    .lineLimit(1)

                Text("wants to be your friend")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 操作按钮
            HStack(spacing: 8) {
                Button {
                    onAccept()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.green)
                        .cornerRadius(100)
                }
                .buttonStyle(.plain)

                Button {
                    onReject()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.red)
                        .cornerRadius(100)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
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