//
//  CreateAgentView.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import SwiftUI

struct CreateAgentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedSkills: Set<String> = []
    
    private let availableSkills = [
        "Code Generation", "Code Review", "Debugging",
        "Data Analysis", "Content Writing", "Translation",
        "Research", "Documentation", "Testing"
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            sidebar
            
            // 表单区域
            formArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Text("My Agents")
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // Agent 列表
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(appViewModel.agentViewModel.agents) { agent in
                        AgentRowView(agent: agent)
                            .cornerRadius(10)
                            .onTapGesture {
                                appViewModel.agentViewModel.selectAgent(agent)
                                dismiss()
                            }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 320)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1),
            alignment: .trailing
        )
    }
    
    // MARK: - Form Area
    
    private var formArea: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 标题
                VStack(spacing: 8) {
                    Text("Create New Agent")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                }
                
                // 表单
                VStack(alignment: .leading, spacing: 24) {
                    // 名称
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Agent Name")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                        
                        TextField("e.g., Code Assistant", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14))
                    }
                    
                    // 描述
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                        
                        TextEditor(text: $description)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .font(.system(size: 14))
                    }
                    
                    // Skills
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Skills")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                        
                        FlowLayout(spacing: 10) {
                            ForEach(availableSkills, id: \.self) { skill in
                                SkillChip(skill: skill, isSelected: selectedSkills.contains(skill)) {
                                    if selectedSkills.contains(skill) {
                                        selectedSkills.remove(skill)
                                    } else {
                                        selectedSkills.insert(skill)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 600)
                
                // 按钮
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button {
                        Task {
                            await createAgent()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Create Agent")
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(name.isEmpty || selectedSkills.isEmpty)
                }
                .padding(.top, 16)
            }
            .padding(80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    private func createAgent() async {
        await appViewModel.agentViewModel.createAgent(
            name: name,
            description: description.isEmpty ? nil : description,
            skills: Array(selectedSkills)
        )
        dismiss()
    }
}

// MARK: - Skill Chip

struct SkillChip: View {
    let skill: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                
                Text(skill)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.white)
            .foregroundStyle(isSelected ? .blue : .secondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CreateAgentView()
        .environment(AppViewModel())
}