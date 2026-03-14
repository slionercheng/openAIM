//
//  FriendDetailView.swift
//  openAIM
//
//  Created by Claude on 2026/3/8.
//

import SwiftUI

struct FriendDetailView: View {
    let friend: Friendship
    @Environment(AppViewModel.self) private var appViewModel

    @State private var showDeleteConfirmation = false
    @State private var isCreatingChat = false
    @State private var isOnline = false
    @State private var onlineCheckTask: Task<Void, Never>?

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
                    if isOnline {
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

                // 在线状态徽章
                HStack(spacing: 6) {
                    Circle()
                        .fill(isOnline ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Text(isOnline ? "Online" : "Offline")
                        .font(.system(size: 13))
                        .foregroundStyle(isOnline ? Color.green : Color.gray)
                }

                // 用户信息
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text(friend.user?.name ?? "Unknown")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231)) // #1E293B

                        // 在线状态标签
                        if isOnline {
                            Text("Online")
                                .font(.system(size: 12))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    Text(friend.user?.email ?? "")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549)) // #64748B
                }

                // 聊天按钮: 200x44, 圆角22px
                Button {
                    startChatWithFriend()
                } label: {
                    HStack(spacing: 8) {
                        if isCreatingChat {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "message")
                                .font(.system(size: 14, weight: .medium))
                        }
                        Text("Start Chat")
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
                .disabled(isCreatingChat)

                // 分隔线 1
                Rectangle()
                    .fill(Color(red: 0.886, green: 0.910, blue: 0.941)) // #E2E8F0
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)

                // 统计行: 间距60px
                HStack(spacing: 60) {
                    // Friends Since
                    VStack(spacing: 4) {
                        Text(friend.createdAt, style: .date)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                        Text("Friends Since")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                    }

                    // Conversations
                    VStack(spacing: 4) {
                        Text("0")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                        Text("Conversations")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                    }

                    // Status
                    VStack(spacing: 4) {
                        Text(isOnline ? "Online" : "Offline")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isOnline ? Color.green : Color.gray)

                        Text("Status")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                    }
                }

                // 分隔线 2
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
                Text(friend.user?.name ?? "This user hasn't added a bio yet.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(red: 0.278, green: 0.337, blue: 0.412)) // #475569
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 删除好友按钮
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.minus")
                            .font(.system(size: 14))
                        Text("Remove Friend")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
            }
            .padding(60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .confirmationDialog(
            "Remove Friend",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove \(friend.user?.name ?? "this friend")", role: .destructive) {
                Task {
                    await appViewModel.friendshipViewModel.deleteFriend(friend)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove this friend? You can send them a friend request again later.")
        }
        .onAppear {
            startOnlineStatusCheck()
        }
        .onDisappear {
            stopOnlineStatusCheck()
        }
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = (friend.user?.name ?? friend.user?.id ?? "").hashValue
        return colors[abs(hash) % colors.count]
    }

    private var avatarInitial: String {
        if let name = friend.user?.name, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        } else if let email = friend.user?.email, !email.isEmpty {
            return String(email.prefix(1)).uppercased()
        }
        return "?"
    }

    // MARK: - 在线状态检查

    private func startOnlineStatusCheck() {
        stopOnlineStatusCheck()

        guard let userId = friend.user?.id else { return }

        // 先尝试使用 API 返回的 online 字段
        if let online = friend.user?.online {
            isOnline = online
        }

        // 立即检查一次
        Task {
            await checkOnlineStatus(userId: userId)
        }

        // 每15秒检查一次
        onlineCheckTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                if Task.isCancelled { break }
                await checkOnlineStatus(userId: userId)
            }
        }
    }

    private func stopOnlineStatusCheck() {
        onlineCheckTask?.cancel()
        onlineCheckTask = nil
    }

    private func checkOnlineStatus(userId: String) async {
        do {
            let online = try await FriendshipService.shared.getUserOnlineStatus(userId: userId)
            await MainActor.run {
                isOnline = online
            }
        } catch {
            logWarn("FriendDetailView", "Failed to check online status: \(error)")
        }
    }

    private func startChatWithFriend() {
        guard let friendId = friend.user?.id else {
            print("[DEBUG] Error: friend.user?.id is nil")
            return
        }

        print("[DEBUG] startChatWithFriend - friend.user?.id: \(friendId)")
        print("[DEBUG] startChatWithFriend - friend.user?.name: \(friend.user?.name ?? "nil")")
        print("[DEBUG] startChatWithFriend - current user ID should be different")

        isCreatingChat = true

        Task {
            // 先检查是否已存在与该好友的会话
            let currentUserId = appViewModel.authViewModel.currentUser?.id
            if let existingConversation = appViewModel.conversationViewModel.conversations.first(where: { conv in
                // 检查是否是 direct 类型的会话，且包含该好友
                guard conv.type == .direct, let participants = conv.participants else { return false }
                // 检查是否有且仅有当前用户和好友两人
                let hasFriend = participants.contains { $0.id == friendId }
                let hasCurrentUser = participants.contains { $0.id == currentUserId }
                return hasFriend && hasCurrentUser && participants.count == 2
            }) {
                // 已存在会话，直接选择它
                print("[DEBUG] Found existing conversation with friend: \(existingConversation.id)")
                await appViewModel.conversationViewModel.selectConversation(existingConversation)
                appViewModel.currentView = .main
                isCreatingChat = false
                return
            }

            // 不存在会话，创建新的
            print("[DEBUG] Creating new conversation with friend")
            await appViewModel.conversationViewModel.createConversation(
                name: nil,
                type: .direct,
                orgId: nil,
                participantIds: [friendId]
            )

            // 切换到主聊天界面
            appViewModel.currentView = .main

            print("[DEBUG] Created chat with friend: \(friend.user?.name ?? "unknown")")

            isCreatingChat = false
        }
    }
}