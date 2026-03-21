//
//  GroupInvitationDetailView.swift
//  openAIM
//
//  Created by Claude on 2026/3/21.
//

import SwiftUI

struct GroupInvitationDetailView: View {
    let invitation: GroupInvitation
    @Environment(AppViewModel.self) private var appViewModel
    @State private var conversationInfo: Conversation?
    @State private var isLoadingInfo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header - 群聊信息
                VStack(spacing: 16) {
                    // 群聊图标
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.1))
                            .frame(width: 120, height: 120)

                        Image(systemName: "person.3.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color(red: 0.231, green: 0.510, blue: 0.965))
                    }

                    // 群聊名称
                    VStack(spacing: 8) {
                        Text(displayConversationName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                        if let conversationId = invitation.conversationId {
                            Text("ID: \(conversationId.prefix(8))...")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))
                        }
                    }

                    // 状态标签
                    statusBadge
                }
                .padding(.top, 40)
                .padding(.bottom, 24)

                Divider()
                    .padding(.horizontal, 32)

                // 邀请者信息
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(title: "Inviter")

                    HStack(spacing: 12) {
                        // 邀请者头像
                        Circle()
                            .fill(inviterAvatarColor)
                            .frame(width: 48, height: 48)
                            .overlay {
                                Text(inviterInitial)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(inviterName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                            Text(inviterEmail)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.945, green: 0.961, blue: 0.969))
                    )
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)

                // 邀请时间
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(title: "Invitation Time")

                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))

                        Text(invitationDate)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.945, green: 0.961, blue: 0.969))
                    )
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)

                // 群聊信息（如果已加载）
                if let conv = conversationInfo {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle(title: "Group Info")

                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "person.2")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))

                                Text("\(conv.participants?.count ?? 0) members")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                                Spacer()
                            }

                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))

                                Text("Created \(formatDate(conv.createdAt))")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                                Spacer()
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.945, green: 0.961, blue: 0.969))
                        )
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                }

                Spacer()

                // 操作按钮
                VStack(spacing: 12) {
                    if invitation.status == .pending {
                        // 管理员邀请，可以直接接受/拒绝
                        Button {
                            Task {
                                await appViewModel.friendshipViewModel.acceptGroupInvitation(invitation)
                            }
                        } label: {
                            Text("Accept Invitation")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(red: 0.133, green: 0.773, blue: 0.369))
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task {
                                await appViewModel.friendshipViewModel.rejectGroupInvitation(invitation)
                            }
                        } label: {
                            Text("Decline")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color(red: 0.937, green: 0.267, blue: 0.267))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(red: 0.937, green: 0.267, blue: 0.267).opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            appViewModel.friendshipViewModel.ignoreGroupInvitation(invitation)
                        } label: {
                            Text("Ignore")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                        }
                        .buttonStyle(.plain)
                    } else if invitation.status == .pendingApproval {
                        // 等待管理员审批
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "hourglass")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color(red: 0.949, green: 0.6, blue: 0.114))

                                Text("Waiting for admin approval")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color(red: 0.949, green: 0.6, blue: 0.114))
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.949, green: 0.6, blue: 0.114).opacity(0.1))
                            )

                            Text("An admin needs to approve your join request before you can join this group.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                                .multilineTextAlignment(.center)

                            Button {
                                appViewModel.friendshipViewModel.ignoreGroupInvitation(invitation)
                            } label: {
                                Text("Cancel Request")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color(red: 0.937, green: 0.267, blue: 0.267))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .onAppear {
            // 如果没有群名称，尝试从会话列表中获取
            if invitation.conversationName == nil || invitation.conversationName?.isEmpty == true {
                if let conversationId = invitation.conversationId {
                    // 先从本地会话列表查找
                    if let existingConv = appViewModel.conversationViewModel.conversations.first(where: { $0.id == conversationId }) {
                        conversationInfo = existingConv
                    } else {
                        // 从服务器获取会话详情
                        Task {
                            isLoadingInfo = true
                            do {
                                conversationInfo = try await ConversationService.shared.getConversation(id: conversationId)
                            } catch {
                                print("[DEBUG] Failed to fetch conversation info: \(error)")
                            }
                            isLoadingInfo = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var displayConversationName: String {
        // 优先使用 invitation 中的名称
        if let name = invitation.conversationName, !name.isEmpty {
            return name
        }
        // 其次使用已加载的会话信息
        if let conv = conversationInfo, let name = conv.name, !name.isEmpty {
            return name
        }
        // 最后显示默认名称
        return "Group Chat"
    }

    private var statusBadge: some View {
        Group {
            if invitation.status == .pending {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.133, green: 0.773, blue: 0.369))
                        .frame(width: 8, height: 8)

                    Text("Pending your response")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.133, green: 0.773, blue: 0.369))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.1))
                )
            } else if invitation.status == .pendingApproval {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.949, green: 0.6, blue: 0.114))
                        .frame(width: 8, height: 8)

                    Text("Waiting for approval")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.949, green: 0.6, blue: 0.114))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(red: 0.949, green: 0.6, blue: 0.114).opacity(0.1))
                )
            }
        }
    }

    private var inviterName: String {
        invitation.inviter?.name ?? "Unknown User"
    }

    private var inviterEmail: String {
        invitation.inviter?.email ?? ""
    }

    private var inviterInitial: String {
        if let name = invitation.inviter?.name, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        } else if let email = invitation.inviter?.email, !email.isEmpty {
            return String(email.prefix(1)).uppercased()
        }
        return "?"
    }

    private var inviterAvatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = (invitation.inviter?.name ?? invitation.inviter?.id ?? "").hashValue
        return colors[abs(hash) % colors.count]
    }

    private var invitationDate: String {
        guard let date = invitation.createdAt else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Section Title

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    GroupInvitationDetailView(invitation: GroupInvitation(
        id: "test-id",
        conversationId: "conv-id",
        conversationName: "Project Team Chat",
        inviterId: "inviter-id",
        inviteeId: "invitee-id",
        status: .pending,
        createdAt: Date(),
        inviter: User(id: "inviter-id", email: "john@example.com", name: "John Doe", avatar: nil, status: nil),
        invitee: nil
    ))
    .environment(AppViewModel())
}