//
//  SearchGroupsView.swift
//  openAIM
//
//  Created by Claude on 2026/3/16.
//

import SwiftUI

struct SearchGroupsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    @State private var searchText = ""
    @State private var searchResults: [GroupSearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var joinRequestMessage: String = ""
    @State private var showJoinSuccess = false
    @State private var selectedGroup: GroupSearchResult?

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("发现群聊")
                    .font(.system(size: 20, weight: .semibold))

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
            .padding(24)

            Divider()

            // 搜索框
            VStack(alignment: .leading, spacing: 12) {
                Text("搜索公开群聊")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    TextField("输入群名称搜索...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            Task {
                                await searchGroups()
                            }
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                            hasSearched = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        Task {
                            await searchGroups()
                        }
                    } label: {
                        Text("搜索")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .disabled(searchText.isEmpty || isSearching)
                }
                .padding(10)
                .background(Color(red: 0.945, green: 0.961, blue: 0.969))
                .cornerRadius(8)
            }
            .padding(24)

            Divider()

            // 搜索结果
            if isSearching {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("搜索中...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hasSearched && searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("未找到相关群聊")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    Text("尝试其他关键词")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("搜索公开群聊")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    Text("输入群名称开始搜索")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(searchResults) { group in
                            GroupSearchRow(group: group) {
                                selectedGroup = group
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 500, height: 600)
        .sheet(item: $selectedGroup) { group in
            GroupJoinSheet(
                group: group,
                onJoin: { message in
                    joinRequestMessage = message
                    showJoinSuccess = true
                    selectedGroup = nil
                }
            )
            .environment(appViewModel)
        }
        .alert("申请已发送", isPresented: $showJoinSuccess) {
            Button("确定") {
                if joinRequestMessage.contains("已加入") {
                    dismiss()
                }
            }
        } message: {
            Text(joinRequestMessage)
        }
    }

    private func searchGroups() async {
        guard !searchText.isEmpty else { return }

        isSearching = true
        hasSearched = true

        do {
            let results = try await ConversationService.shared.searchPublicGroups(query: searchText)
            searchResults = results
        } catch {
            print("[ERROR] Failed to search groups: \(error)")
            searchResults = []
        }

        isSearching = false
    }
}

// MARK: - Group Search Row

struct GroupSearchRow: View {
    let group: GroupSearchResult
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                // 群头像
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(avatarColor)
                        .frame(width: 56, height: 56)

                    Text(avatarInitial)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                // 群信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name ?? "未命名群聊")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label("\(group.participantCount ?? 0) 人", systemImage: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        if let creatorName = group.creatorName {
                            Text("创建者: \(creatorName)")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = (group.name ?? group.id).hashValue
        return colors[abs(hash) % colors.count]
    }

    private var avatarInitial: String {
        if let name = group.name, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return "群"
    }
}

// MARK: - Group Join Sheet

struct GroupJoinSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    let group: GroupSearchResult
    let onJoin: (String) -> Void

    @State private var message = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 24) {
            // 群信息
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(avatarColor)
                        .frame(width: 80, height: 80)

                    Text(avatarInitial)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(group.name ?? "未命名群聊")
                    .font(.system(size: 20, weight: .semibold))

                HStack(spacing: 16) {
                    Label("\(group.participantCount ?? 0) 成员", systemImage: "person.2.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    if let creatorName = group.creatorName {
                        Text("创建者: \(creatorName)")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // 申请消息
            VStack(alignment: .leading, spacing: 8) {
                Text("申请消息（可选）")
                    .font(.system(size: 14, weight: .medium))

                TextEditor(text: $message)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(red: 0.945, green: 0.961, blue: 0.969))
                    .cornerRadius(8)
                    .font(.system(size: 14))
            }

            Spacer()

            // 按钮
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button {
                    Task {
                        await submitJoinRequest()
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("申请加入")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting)
            }
        }
        .padding(24)
        .frame(width: 400, height: 400)
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = (group.name ?? group.id).hashValue
        return colors[abs(hash) % colors.count]
    }

    private var avatarInitial: String {
        if let name = group.name, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return "群"
    }

    private func submitJoinRequest() async {
        isSubmitting = true

        do {
            let result = try await ConversationService.shared.createJoinRequest(
                conversationId: group.id,
                message: message.isEmpty ? nil : message
            )

            if result.status == .accepted {
                // 直接加入了（如果群设置允许直接加入）
                onJoin("您已成功加入该群聊")

                // 刷新会话列表
                await appViewModel.conversationViewModel.loadConversations()
            } else {
                onJoin("您的加入申请已发送，等待管理员审批")
            }

            dismiss()
        } catch {
            print("[ERROR] Failed to submit join request: \(error)")
            onJoin("申请失败，请稍后重试")
            dismiss()
        }

        isSubmitting = false
    }
}

#Preview {
    SearchGroupsView()
        .environment(AppViewModel())
}