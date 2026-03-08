//
//  AgentListView.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import SwiftUI

struct AgentListView: View {
    @Environment(AppViewModel.self) private var appViewModel
    
    @State private var searchText = ""
    @State private var showCreateAgent = false
    
    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            agentSidebar
            
            // 详情区域
            if let agent = appViewModel.agentViewModel.selectedAgent {
                AgentDetailView(agent: agent)
            } else {
                emptyView
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
        .sheet(isPresented: $showCreateAgent) {
            CreateAgentView()
        }
    }
    
    // MARK: - Agent Sidebar
    
    private var agentSidebar: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Text("My Agents")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Button {
                    showCreateAgent = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Create")
                    }
                    .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(16)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // 搜索框
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                
                TextField("Search agents...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Agent 列表
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredAgents) { agent in
                        AgentRowView(agent: agent)
                            .background(
                                appViewModel.agentViewModel.selectedAgent?.id == agent.id
                                    ? Color.blue.opacity(0.1)
                                    : Color.clear
                            )
                            .cornerRadius(10)
                            .onTapGesture {
                                appViewModel.agentViewModel.selectAgent(agent)
                            }
                    }
                }
                .padding(.horizontal, 12)
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
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Select an agent to view details")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
    }
    
    private var filteredAgents: [Agent] {
        if searchText.isEmpty {
            return appViewModel.agentViewModel.agents
        }
        return appViewModel.agentViewModel.agents.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Agent Row View

struct AgentRowView: View {
    let agent: Agent
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            RoundedRectangle(cornerRadius: 10)
                .fill(avatarColor)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "cpu")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(agent.name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                
                Text(agent.description ?? "No description")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 状态
            HStack(spacing: 6) {
                Circle()
                    .fill(agent.status == .active ? .green : .gray)
                    .frame(width: 8, height: 8)
                
                Text(agent.status == .active ? "Active" : "Inactive")
                    .font(.system(size: 12))
                    .foregroundStyle(agent.status == .active ? .green : .secondary)
            }
        }
        .padding(12)
    }
    
    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink]
        let index = abs(agent.name.hashValue) % colors.count
        return colors[index]
    }
}

#Preview {
    AgentListView()
        .environment(AppViewModel())
}