//
//  SettingsView.swift
//  openAIM
//
//  Created by Claude on 2026/3/8.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 用户信息
                userInfoSection
                
                // 通用设置
                generalSection
                
                // 账户设置
                accountSection
                
                // 关于
                aboutSection
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
    }
    
    // MARK: - User Info Section
    
    private var userInfoSection: some View {
        HStack(spacing: 20) {
            Circle()
                .fill(Color.blue)
                .frame(width: 80, height: 80)
                .overlay {
                    Text(appViewModel.authViewModel.currentUser?.name?.prefix(1) ?? "U")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(appViewModel.authViewModel.currentUser?.name ?? "User")
                    .font(.system(size: 24, weight: .bold))
                
                Text(appViewModel.authViewModel.currentUser?.email ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                // TODO: 编辑个人资料
            } label: {
                Text("Edit Profile")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
    
    // MARK: - General Section
    
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.system(size: 16, weight: .semibold))
            
            VStack(spacing: 0) {
                settingsRow(icon: "bell", title: "Notifications", subtitle: "Manage notification preferences")
                Divider().padding(.leading, 44)
                settingsRow(icon: "paintbrush", title: "Appearance", subtitle: "Theme and display options")
                Divider().padding(.leading, 44)
                settingsRow(icon: "globe", title: "Language", subtitle: "English")
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4)
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .font(.system(size: 16, weight: .semibold))
            
            VStack(spacing: 0) {
                settingsRow(icon: "key", title: "Change Password", subtitle: "Update your password")
                Divider().padding(.leading, 44)
                settingsRow(icon: "externaldrive", title: "Data & Storage", subtitle: "Manage your data")
                Divider().padding(.leading, 44)
                settingsRow(icon: "shield", title: "Privacy & Security", subtitle: "Manage privacy settings")
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4)
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.system(size: 16, weight: .semibold))
            
            VStack(spacing: 0) {
                settingsRow(icon: "info.circle", title: "About OpenAIM", subtitle: "Version 1.0.0")
                Divider().padding(.leading, 44)
                settingsRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Get help with OpenAIM")
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4)
        }
    }
    
    // MARK: - Settings Row
    
    private func settingsRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture {
            // TODO: 导航到对应设置页面
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppViewModel())
}