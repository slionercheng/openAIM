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
        Button {
            appViewModel.friendshipViewModel.selectUser(user)
        } label: {
            HStack(spacing: 12) {
                // 头像: 40x40, 圆形
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(avatarColor)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Text(avatarInitial)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                    // 在线状态指示器
                    if user.online == true {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 10, height: 10)
                            }
                            .offset(x: 2, y: 2)
                    }
                }

                // 用户信息
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(user.name ?? user.email)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231)) // #1E293B
                            .lineLimit(1)

                        // 在线状态标签
                        if user.online == true {
                            Text("Online")
                                .font(.system(size: 10))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    Text(user.email)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549)) // #64748B
                        .lineLimit(1)
                }

                Spacer()

                // Add Friend 按钮
                Button {
                    Task {
                        await appViewModel.friendshipViewModel.sendFriendRequest(to: user)
                    }
                } label: {
                    Text("Add")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: 0.231, green: 0.510, blue: 0.965)) // #3B82F6
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                        ? Color(red: 0.937, green: 0.965, blue: 1.0) // #EFF6FF
                        : .white)
            )
        }
        .buttonStyle(.plain)
    }

    private var isSelected: Bool {
        appViewModel.friendshipViewModel.selectedUser?.id == user.id
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
        ScrollView {
            VStack(spacing: 24) {
                // 头像: 120x120, 圆角28px
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(avatarColor)
                        .frame(width: 120, height: 120)
                        .overlay {
                            Text(avatarInitial)
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                    // 在线状态指示器
                    if user.online == true {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 32, height: 32)
                            .overlay {
                                Circle()
                                .fill(Color.green)
                                .frame(width: 24, height: 24)
                            }
                            .offset(x: 4, y: 4)
                    }
                }

                // 用户信息
                VStack(spacing: 8) {
                    Text(user.name ?? "Unknown")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231)) // #1E293B

                    HStack(spacing: 6) {
                        Text(user.email)
                            .font(.system(size: 15))
                            .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549)) // #64748B

                        // 在线状态标签
                        if user.online == true {
                            Text("Online")
                                .font(.system(size: 12))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        } else {
                            Text("Offline")
                                .font(.system(size: 12))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray)
                                .cornerRadius(4)
                        }
                    }
                }

                // Add Friend 按钮: 200x44, 圆角22px
                Button {
                    Task {
                        await appViewModel.friendshipViewModel.sendFriendRequest(to: user)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18))
                        Text("Add Friend")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color(red: 0.231, green: 0.510, blue: 0.965)) // #3B82F6
                    )
                }
                .buttonStyle(.plain)

                // 分隔线
                Rectangle()
                    .fill(Color(red: 0.886, green: 0.910, blue: 0.941)) // #E2E8F0
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)

                // 统计行
                HStack(spacing: 60) {
                    // Member Since
                    VStack(spacing: 4) {
                        Text("Mar 2026")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                        Text("Member Since")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                    }

                    // Mutual Friends
                    VStack(spacing: 4) {
                        Text("5")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                        Text("Mutual Friends")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                    }

                    // Status
                    VStack(spacing: 4) {
                        Text(user.online == true ? "Online" : "Offline")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(user.online == true ? Color.green : Color.gray)

                        Text("Status")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                    }
                }

                // 分隔线
                Rectangle()
                    .fill(Color(red: 0.886, green: 0.910, blue: 0.941)) // #E2E8F0
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)

                // About 标题
                HStack {
                    Text("About")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                    Spacer()
                }

                // Bio 文字
                Text(user.name ?? "This user hasn't added a bio yet.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(red: 0.278, green: 0.337, blue: 0.412)) // #475569
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
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