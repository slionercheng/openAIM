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
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(mockParticipants, id: \.self) { participant in
                                HStack {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 32, height: 32)
                                    
                                    Text(participant)
                                        .font(.system(size: 14))
                                    
                                    Spacer()
                                    
                                    Image(systemName: selectedParticipants.contains(participant) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedParticipants.contains(participant) ? .blue : .secondary)
                                }
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .onTapGesture {
                                    if selectedParticipants.contains(participant) {
                                        selectedParticipants.remove(participant)
                                    } else {
                                        selectedParticipants.insert(participant)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
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
    
    private var mockParticipants: [String] {
        ["AI Assistant", "John Doe", "Alice Smith", "Bob Johnson"]
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