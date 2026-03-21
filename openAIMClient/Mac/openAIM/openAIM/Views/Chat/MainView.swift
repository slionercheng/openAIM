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
    @State private var showSearchGroups = false
    @State private var isDirectExpanded = true
    @State private var isGroupExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("Messages")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                Spacer()

                // 发现群聊按钮
                Button {
                    showSearchGroups = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.945, green: 0.961, blue: 0.969))
                            .frame(width: 32, height: 32)

                        Image(systemName: "globe")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                    }
                }
                .buttonStyle(.plain)
                .help("发现群聊")

                // 新建会话按钮
                Button {
                    showNewChat = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.945, green: 0.961, blue: 0.969))
                            .frame(width: 32, height: 32)

                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                    }
                }
                .buttonStyle(.plain)
                .help("新建会话")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .overlay(
                Rectangle()
                    .fill(Color(red: 0.886, green: 0.910, blue: 0.941))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // 搜索框
            SearchBar(text: $searchText)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            
            // 会话列表
            ScrollView {
                LazyVStack(spacing: 4) {
                    // 直接消息分组
                    if !directConversations.isEmpty {
                        CollapsibleSectionHeader(
                            title: "Direct Messages",
                            icon: "person.fill",
                            count: directConversations.count,
                            isExpanded: $isDirectExpanded
                        )

                        if isDirectExpanded {
                            ForEach(directConversations) { conversation in
                                ConversationRowView(
                                    conversation: conversation,
                                    currentUserId: appViewModel.authViewModel.currentUser?.id,
                                    unreadCount: appViewModel.conversationViewModel.getUnreadCount(conversation.id),
                                    onDelete: {
                                        Task {
                                            await appViewModel.conversationViewModel.deleteConversation(conversation)
                                        }
                                    }
                                )
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
                    }

                    // 群聊分组
                    if !groupConversations.isEmpty {
                        CollapsibleSectionHeader(
                            title: "Group Chats",
                            icon: "person.3.fill",
                            count: groupConversations.count,
                            isExpanded: $isGroupExpanded
                        )

                        if isGroupExpanded {
                            ForEach(groupConversations) { conversation in
                                ConversationRowView(
                                    conversation: conversation,
                                    currentUserId: appViewModel.authViewModel.currentUser?.id,
                                    unreadCount: appViewModel.conversationViewModel.getUnreadCount(conversation.id),
                                    onDelete: {
                                        Task {
                                            await appViewModel.conversationViewModel.deleteConversation(conversation)
                                        }
                                    }
                                )
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
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(red: 0.886, green: 0.910, blue: 0.941))
                .frame(width: 1),
            alignment: .trailing
        )
        .sheet(isPresented: $showNewChat) {
            NewConversationView()
        }
        .sheet(isPresented: $showSearchGroups) {
            SearchGroupsView()
        }
    }
    
    private var filteredConversations: [Conversation] {
        let allConversations = appViewModel.conversationViewModel.conversations
        guard !searchText.isEmpty else { return allConversations }

        let query = searchText.lowercased()
        let currentUserId = appViewModel.authViewModel.currentUser?.id
        return allConversations.filter { conv in
            matchesSearch(conv, query: query, currentUserId: currentUserId)
        }
    }

    private var directConversations: [Conversation] {
        filteredConversations.filter { $0.type == .direct }
    }

    private var groupConversations: [Conversation] {
        filteredConversations.filter { $0.type == .group }
    }

    private func matchesSearch(_ conversation: Conversation, query: String, currentUserId: String?) -> Bool {
        // 搜索会话名称
        if let name = conversation.name, name.lowercased().contains(query) {
            return true
        }
        // 搜索最后一条消息内容
        if let content = conversation.lastMessage?.content, content.lowercased().contains(query) {
            return true
        }
        // 搜索参与者名字（排除当前用户自己）
        if let participants = conversation.participants {
            for p in participants {
                // 排除当前用户
                if p.id == currentUserId { continue }
                if let name = p.name, name.lowercased().contains(query) { return true }
            }
        }
        return false
    }
}

// MARK: - Collapsible Section Header

struct CollapsibleSectionHeader: View {
    let title: String
    let icon: String
    let count: Int
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                    .frame(width: 16)

                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.231, green: 0.510, blue: 0.965))

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                Text("(\(count))")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.58, green: 0.635, blue: 0.722))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Conversation Row View

struct ConversationRowView: View {
    let conversation: Conversation
    let currentUserId: String?
    let unreadCount: Int
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 0) {
            // 删除按钮（悬浮时显示）
            if isHovered {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .padding(.trailing, 8)
            }

            HStack(spacing: 12) {
                // 头像
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(avatarColor)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Text(displayInitial)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                    // 未读消息小红点
                    if unreadCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .offset(x: 6, y: -6)
                    }
                }

                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 15, weight: unreadCount > 0 ? .semibold : .medium))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                        .lineLimit(1)

                    Text(conversation.lastMessage?.content ?? "No messages")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                        .lineLimit(1)
                }

                Spacer()

                // 时间
                Text(timeString)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            unreadCount > 0 ? Color.blue.opacity(0.05) : Color.clear
        )
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .confirmationDialog(
            "删除会话",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除此会话", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除与 \(displayName) 的会话吗？")
        }
    }
    
    // 显示名称：优先使用参与者名字，其次使用会话名称
    private var displayName: String {
        // 如果是 direct 类型会话，显示对方的名字
        if conversation.type == .direct, let participants = conversation.participants {
            let otherParticipant = participants.first { $0.id != currentUserId }
            if let name = otherParticipant?.name, !name.isEmpty {
                return name
            }
        }
        // 否则显示会话名称
        return conversation.name ?? "Conversation"
    }
    
    // 显示首字母
    private var displayInitial: String {
        if conversation.type == .direct, let participants = conversation.participants {
            let otherParticipant = participants.first { $0.id != currentUserId }
            if let name = otherParticipant?.name, !name.isEmpty {
                return String(name.prefix(2))
            }
        }
        return String(conversation.name?.prefix(2) ?? "AI")
    }
    
    private var avatarColor: Color {
        switch conversation.type {
        case .direct: return .blue
        case .group: return .purple
        }
    }
    
    private var timeString: String {
        let date = conversation.lastMessage?.createdAt ?? conversation.updatedAt ?? conversation.createdAt
        
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
                .foregroundStyle(Color.gray)
            
            Text("Select a conversation to start chatting")
                .font(.system(size: 16))
                .foregroundStyle(Color.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
    }
}

#Preview {
    MainView()
        .environment(AppViewModel())
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Search conversations...")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 0.58, green: 0.64, blue: 0.72))
                }

                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))
                    .tint(Color.blue)
            }
        }
        .padding(10)
        .background(Color(red: 0.945, green: 0.961, blue: 0.969))
        .cornerRadius(8)
    }
}
