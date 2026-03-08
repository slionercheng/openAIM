//
//  SearchUsersView.swift
//  openAIM
//
//  Created by Claude on 2026/3/8.
//

import SwiftUI

struct SearchUsersView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Text("Add Friend")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )

            // 搜索框
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    TextField("Search by email or name...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            performSearch()
                        }
                        .focused($isSearchFocused)
                }
                .padding(10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Button {
                    performSearch()
                } label: {
                    Text("Search")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(searchQuery.isEmpty)
            }
            .padding(16)

            Divider()

            // 搜索结果
            if appViewModel.friendshipViewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appViewModel.friendshipViewModel.searchResults.isEmpty {
                if searchQuery.isEmpty {
                    // 初始状态
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("Search for users by email or name")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 无结果
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("No users found")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)

                        Text("Try a different search term")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // 结果列表
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(appViewModel.friendshipViewModel.searchTotal) results")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)

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
        .frame(width: 400, height: 500)
        .onAppear {
            isSearchFocused = true
            appViewModel.friendshipViewModel.clearSearch()
        }
    }

    private func performSearch() {
        guard !searchQuery.isEmpty else { return }

        Task {
            appViewModel.friendshipViewModel.searchQuery = searchQuery
            await appViewModel.friendshipViewModel.searchUsers()
        }
    }
}

// MARK: - Search User Row View

struct SearchUserRowView: View {
    let user: SearchUser
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
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
                Text(user.name ?? user.email)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                Text(user.email)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 根据状态显示不同按钮
            actionButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch user.friendshipStatus {
        case .none:
            Button {
                Task {
                    await appViewModel.friendshipViewModel.sendFriendRequest(to: user)
                }
            } label: {
                Text("Add")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

        case .pendingSent:
            Text("Request Sent")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)

        case .accepted:
            Button {
                // TODO: 发起聊天
            } label: {
                Text("Message")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .pendingReceived:
            Text("Requested You")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)

        default:
            EmptyView()
        }
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = (user.name ?? user.id).hashValue
        return colors[abs(hash) % colors.count]
    }

    private var avatarInitial: String {
        if let name = user.name, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return String(user.email.prefix(1)).uppercased()
    }
}

// MARK: - Search User Detail View (for main area display)

struct SearchUserDetailView: View {
    let user: SearchUser
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        VStack(spacing: 24) {
            // 头像
            Circle()
                .fill(avatarColor)
                .frame(width: 100, height: 100)
                .overlay {
                    Text(avatarInitial)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                }

            // 用户信息
            VStack(spacing: 8) {
                Text(user.name ?? "Unknown")
                    .font(.system(size: 24, weight: .semibold))

                Text(user.email)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            // 操作按钮
            switch user.friendshipStatus {
            case .none:
                Button {
                    Task {
                        await appViewModel.friendshipViewModel.sendFriendRequest(to: user)
                    }
                } label: {
                    Label("Add Friend", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: 200)

            case .pendingSent:
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                    Text("Friend Request Sent")
                }
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

            case .accepted:
                Button {
                    // TODO: 发起聊天
                } label: {
                    Label("Send Message", systemImage: "message")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: 200)

            case .pendingReceived:
                VStack(spacing: 12) {
                    Text("This user sent you a friend request")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button("Accept") {
                            // TODO: 接受请求
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Decline") {
                            // TODO: 拒绝请求
                        }
                        .buttonStyle(.bordered)
                    }
                }

            default:
                EmptyView()
            }

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = (user.name ?? user.id).hashValue
        return colors[abs(hash) % colors.count]
    }

    private var avatarInitial: String {
        if let name = user.name, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return String(user.email.prefix(1)).uppercased()
    }
}

#Preview {
    SearchUsersView()
        .environment(AppViewModel())
}