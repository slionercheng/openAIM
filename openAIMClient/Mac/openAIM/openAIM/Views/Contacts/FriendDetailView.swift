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
                Text(friend.user?.name ?? "Unknown")
                    .font(.system(size: 24, weight: .semibold))

                Text(friend.user?.email ?? "")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            // 操作按钮
            HStack(spacing: 16) {
                Button {
                    // TODO: 发起聊天
                } label: {
                    Label("Message", systemImage: "message")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    showDeleteConfirmation = true
                } label: {
                    Label("Remove", systemImage: "person.badge.minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .foregroundStyle(.red)
            }
            .frame(maxWidth: 300)

            Spacer()

            // 好友信息
            VStack(spacing: 16) {
                HStack {
                    Text("Friends since")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(friend.createdAt, style: .date)
                        .font(.system(size: 14, weight: .medium))
                }

                Divider()

                HStack {
                    Text("Status")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(statusText)
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }
            .padding(20)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            .frame(maxWidth: 400)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
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

    private var statusColor: Color {
        switch friend.user?.status {
        case .active:
            return .green
        case .inactive:
            return .orange
        case .offline:
            return .gray
        case .none:
            return .gray
        }
    }

    private var statusText: String {
        switch friend.user?.status {
        case .active:
            return "Online"
        case .inactive:
            return "Away"
        case .offline:
            return "Offline"
        case .none:
            return "Unknown"
        }
    }
}