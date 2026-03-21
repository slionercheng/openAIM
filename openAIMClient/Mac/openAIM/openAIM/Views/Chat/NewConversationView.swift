//
//  NewConversationView.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import SwiftUI

struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    @State private var name = ""
    @State private var selectedType: ConversationType = .direct
    @State private var selectedParticipants: Set<String> = []
    @State private var showExistingConversationAlert = false
    @State private var searchText = ""
    @State private var isPublic = true  // 群聊是否公开，默认公开

    var body: some View {
        VStack(spacing: 24) {
            // 标题
            HStack {
                Text("New Conversation")
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

            // 表单
            VStack(alignment: .leading, spacing: 16) {
                // 类型选择
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conversation Type")
                        .font(.system(size: 14, weight: .medium))

                    HStack(spacing: 16) {
                        RadioButton(label: "Direct", isSelected: selectedType == .direct) {
                            selectedType = .direct
                            selectedParticipants.removeAll()
                        }

                        RadioButton(label: "Group", isSelected: selectedType == .group) {
                            selectedType = .group
                            selectedParticipants.removeAll()
                        }
                    }
                }

                // 名称（群聊时显示）
                if selectedType == .group {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group Name")
                            .font(.system(size: 14, weight: .medium))

                        TextField("Enter group name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 公开群聊开关
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Public Group")
                                .font(.system(size: 14, weight: .medium))

                            Spacer()

                            Toggle("", isOn: $isPublic)
                                .labelsHidden()
                        }

                        Text(isPublic ? "Anyone can search and find this group" : "Only invited members can join")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                // 搜索框
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedType == .direct ? "Select Friend" : "Select Members")
                        .font(.system(size: 14, weight: .medium))

                    // 搜索输入框
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)

                        TextField("Search friends...", text: $searchText)
                            .textFieldStyle(.plain)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(Color(red: 0.945, green: 0.961, blue: 0.969))
                    .cornerRadius(8)
                }

                // 选择参与者
                if filteredParticipants.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)

                        Text(searchText.isEmpty ? "No friends available" : "No friends found")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(filteredParticipants) { user in
                                ParticipantSelectionRow(
                                    user: user,
                                    isSelected: selectedParticipants.contains(user.id),
                                    isMultiSelect: selectedType == .group
                                ) {
                                    if selectedParticipants.contains(user.id) {
                                        selectedParticipants.remove(user.id)
                                    } else {
                                        // 私聊只能选一个
                                        if selectedType == .direct {
                                            selectedParticipants = [user.id]
                                        } else {
                                            selectedParticipants.insert(user.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                }

                // 已选择的成员预览（群聊时显示）
                if selectedType == .group && !selectedParticipants.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected (\(selectedParticipants.count))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedParticipants), id: \.self) { userId in
                                    if let user = allFriends.first(where: { $0.id == userId }) {
                                        SelectedMemberChip(user: user) {
                                            selectedParticipants.remove(userId)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(height: 36)
                    }
                }
            }

            Spacer()

            // 按钮
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    Task {
                        await createConversation()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 400, height: 550)
        .alert("会话已存在", isPresented: $showExistingConversationAlert) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("与该用户的私聊会话已存在，已为您打开现有会话")
        }
    }

    // MARK: - Computed Properties

    /// 所有好友列表
    private var allFriends: [User] {
        appViewModel.friendshipViewModel.friends.compactMap { $0.user }
    }

    /// 过滤后的参与者列表
    private var filteredParticipants: [User] {
        let friends = allFriends

        guard !searchText.isEmpty else {
            return friends
        }

        let query = searchText.lowercased()
        return friends.filter { user in
            (user.name?.lowercased().contains(query) ?? false) ||
            user.email.lowercased().contains(query)
        }
    }

    private var isValid: Bool {
        guard !selectedParticipants.isEmpty else { return false }

        if selectedType == .group {
            // 群聊需要至少2个成员且有名称
            return !name.isEmpty && selectedParticipants.count >= 1
        }

        return true
    }

    // MARK: - Actions

    private func createConversation() async {
        let created = await appViewModel.conversationViewModel.createConversation(
            name: selectedType == .group ? name : nil,
            type: selectedType,
            isPublic: selectedType == .group ? isPublic : false,
            participantIds: Array(selectedParticipants)
        )

        // 如果是私聊且找到了已存在的会话，显示提示
        if !created && selectedType == .direct {
            showExistingConversationAlert = true
        } else {
            dismiss()
        }
    }
}

// MARK: - Selected Member Chip

struct SelectedMemberChip: View {
    let user: User
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(user.name ?? user.email)
                .font(.system(size: 12))
                .lineLimit(1)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Participant Selection Row

struct ParticipantSelectionRow: View {
    let user: User
    let isSelected: Bool
    let isMultiSelect: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
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
                    Text(user.name ?? user.email)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(user.email)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isSelected ? (isMultiSelect ? "checkmark.circle.fill" : "largecircle.fill.circle") : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
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

// MARK: - Radio Button

struct RadioButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NewConversationView()
        .environment(AppViewModel())
}