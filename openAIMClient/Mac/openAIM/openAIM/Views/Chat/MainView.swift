//
//  MainView.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import SwiftUI

struct MainView: View {
    @Environment(AppViewModel.self) private var appViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            SidebarView()
                .frame(width: 280)
            
            // 聊天区域
            if let conversation = appViewModel.conversationViewModel.selectedConversation {
                ChatView(conversation: conversation)
            } else {
                EmptyChatView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Environment(AppViewModel.self) private var appViewModel
    
    @State private var searchText = ""
    @State private var showNewChat = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("Messages")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Button {
                    showNewChat = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
                
                TextField("Search conversations...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            
            // 会话列表
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredConversations) { conversation in
                        ConversationRowView(conversation: conversation)
                            .background(
                                appViewModel.conversationViewModel.selectedConversation?.id == conversation.id
                                    ? Color.blue.opacity(0.1)
                                    : Color.clear
                            )
                            .cornerRadius(8)
                            .onTapGesture {
                                Task {
                                    await appViewModel.conversationViewModel.selectConversation(conversation)
                                }
                            }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1),
            alignment: .trailing
        )
        .sheet(isPresented: $showNewChat) {
            NewConversationView()
        }
    }
    
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return appViewModel.conversationViewModel.conversations
        }
        return appViewModel.conversationViewModel.conversations.filter {
            ($0.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.lastMessage?.content.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
}

// MARK: - Conversation Row View

struct ConversationRowView: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            Circle()
                .fill(avatarColor)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(conversation.name?.prefix(2) ?? "AI")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.name ?? "Conversation")
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                
                Text(conversation.lastMessage?.content ?? "No messages")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 时间和未读数
            VStack(alignment: .trailing, spacing: 4) {
                Text(timeString)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(100)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    private var avatarColor: Color {
        switch conversation.type {
        case .direct: return .blue
        case .group: return .purple
        }
    }
    
    private var timeString: String {
        let date = conversation.lastMessage?.createdAt ?? conversation.updatedAt
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Empty Chat View

struct EmptyChatView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Select a conversation to start chatting")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
    }
}

#Preview {
    MainView()
        .environment(AppViewModel())
}