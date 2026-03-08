//
//  ContactsView.swift
//  openAIM
//
//  Created by Claude on 2026/3/8.
//

import SwiftUI

struct ContactsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            contactsSidebar
            
            // 主区域
            if appViewModel.currentView == .contacts {
                // TODO: 实现好友详情视图
                emptyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Contacts Sidebar
    
    private var contactsSidebar: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Text("Contacts")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Button {
                    // TODO: 添加好友
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
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
                
                TextField("Search contacts...", text: .constant(""))
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 好友请求入口
            Button {
                // TODO: 显示好友请求
            } label: {
                HStack {
                    Image(systemName: "person.badge.clock")
                        .font(.system(size: 16))
                    
                    Text("Friend Requests")
                        .font(.system(size: 14))
                    
                    Spacer()
                    
                    if true { // TODO: 有待处理请求时显示
                        Text("3")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(100)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.05))
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // 联系人列表
            ScrollView {
                LazyVStack(spacing: 4) {
                    Text("Friends")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    // TODO: 显示好友列表
                    ForEach(0..<5) { _ in
                        ContactRowView()
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 280)
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
            Image(systemName: "person.2")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Select a contact to view details")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
    }
}

// MARK: - Contact Row View

struct ContactRowView: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 44, height: 44)
                .overlay {
                    Text("A")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("User Name")
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                
                Text("user@example.com")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

#Preview {
    ContactsView()
        .environment(AppViewModel())
}