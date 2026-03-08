//
//  AgentDetailView.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import SwiftUI

struct AgentDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    
    let agent: Agent
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 头部信息 - App Store 风格
                profileHeader
                
                Divider()
                    .padding(.horizontal, 40)
                
                // 统计行
                statsRow
                
                Divider()
                    .padding(.horizontal, 40)
                
                // Skills
                skillsSection
                
                Divider()
                    .padding(.horizontal, 40)
                
                // Access Token
                tokenSection
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 24) {
            // 头像 + 状态
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 28)
                    .fill(avatarColor)
                    .frame(width: 120, height: 120)
                    .overlay {
                        Image(systemName: "cpu")
                            .font(.system(size: 48))
                            .foregroundStyle(.white)
                    }
                
                // 状态标识
                HStack(spacing: 6) {
                    Circle()
                        .fill(agent.status == .active ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(agent.status == .active ? "Active" : "Inactive")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(agent.status == .active ? .green : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white)
                .cornerRadius(100)
                .shadow(color: .black.opacity(0.1), radius: 2)
                .offset(x: 0, y: 4)
            }
            
            // 名称和描述
            VStack(spacing: 8) {
                Text(agent.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                Text(agent.description ?? "No description available")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // 开始聊天按钮
            Button {
                // TODO: 开始与 Agent 聊天
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 16))
                    Text("Start Chat")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(width: 200, height: 44)
                .foregroundStyle(.white)
                .background(Color.blue)
                .cornerRadius(22)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 60) {
            statItem(value: "24", label: "Conversations")
            statItem(value: "3", label: "Organizations")
            statItem(value: agent.status == .active ? "Active" : "Inactive", label: "Status")
        }
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
            
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Skills Section
    
    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Skills")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
            
            if agent.skills.isEmpty {
                Text("No skills configured")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(agent.skills, id: \.self) { skill in
                        Text(skill)
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Token Section
    
    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Access Token")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
            
            // Token 显示
            HStack {
                Text("agt_secret_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button {
                    // TODO: 复制 Token
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            
            // 重新生成按钮
            Button {
                Task {
                    await appViewModel.agentViewModel.regenerateToken(agentId: agent.id)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                    Text("Regenerate")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var avatarColor: Color {
        let colors: [Color] = [
            Color(red: 0.545, green: 0.361, blue: 0.965),  // Purple
            Color(red: 0.961, green: 0.620, blue: 0.043),  // Orange
            Color(red: 0.063, green: 0.725, blue: 0.506),  // Green
            Color(red: 0.231, green: 0.510, blue: 0.965),  // Blue
            Color(red: 0.941, green: 0.267, blue: 0.459)   // Pink
        ]
        let index = abs(agent.name.hashValue) % colors.count
        return colors[index]
    }
}

#Preview {
    AgentDetailView(agent: Agent(
        id: "agent_123",
        name: "Code Assistant",
        description: "Helps with programming tasks and code review",
        skills: ["Code Generation", "Code Review", "Debugging"],
        accessToken: nil,
        status: .active,
        createdAt: Date(),
        updatedAt: Date()
    ))
    .environment(AppViewModel())
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}