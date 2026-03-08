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
                        }
                        
                        RadioButton(label: "Group", isSelected: selectedType == .group) {
                            selectedType = .group
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
                }
                
                // 选择参与者
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Participants")
                        .font(.system(size: 14, weight: .medium))

                    if availableParticipants.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)

                            Text("No friends available")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(availableParticipants) { user in
                                    ParticipantSelectionRow(
                                        user: user,
                                        isSelected: selectedParticipants.contains(user.id)
                                    ) {
                                        if selectedParticipants.contains(user.id) {
                                            selectedParticipants.remove(user.id)
                                        } else {
                                            selectedParticipants.insert(user.id)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
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
                        await appViewModel.conversationViewModel.createConversation(
                            name: selectedType == .group ? name : nil,
                            type: selectedType,
                            participantIds: Array(selectedParticipants)
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedParticipants.isEmpty || (selectedType == .group && name.isEmpty))
            }
        }
        .padding(24)
        .frame(width: 400, height: 500)
    }

    private var availableParticipants: [User] {
        appViewModel.friendshipViewModel.friends.compactMap { $0.user }
    }
}

// MARK: - Participant Selection Row

struct ParticipantSelectionRow: View {
    let user: User
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(avatarInitial)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name ?? user.email)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)

                    Text(user.email)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
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