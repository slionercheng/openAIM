//
//  NavigationRail.swift
//  openAIM
//
//  Created by Claude on 2026/3/8.
//

import SwiftUI

/// Navigation Rail - 左侧导航栏
struct NavigationRail: View {
    @Environment(AppViewModel.self) private var appViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Logo
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue)
                    .frame(width: 40, height: 40)
                Text("OA")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 4)
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 32, height: 1)
                .padding(.bottom, 4)
            
            // Chat
            navButton(
                icon: "message.fill",
                isActive: appViewModel.currentView == .main,
                action: { appViewModel.currentView = .main }
            )
            
            // Contacts
            navButton(
                icon: "person.2.fill",
                isActive: appViewModel.currentView == .contacts,
                action: { appViewModel.currentView = .contacts }
            )
            
            // Agents
            navButton(
                icon: "cpu.fill",
                isActive: appViewModel.currentView == .agents,
                action: { appViewModel.currentView = .agents }
            )
            
            Spacer()
            
            // Settings
            navButton(
                icon: "gearshape.fill",
                isActive: appViewModel.currentView == .settings,
                action: { appViewModel.currentView = .settings }
            )
            
            // User Avatar
            Button {
                // TODO: 用户菜单
            } label: {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(appViewModel.authViewModel.currentUser?.name?.prefix(1) ?? "U")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .frame(width: 64)
        .background(Color(red: 0.118, green: 0.161, blue: 0.231)) // #1E293B
    }
    
    private func navButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.2))
                }
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isActive ? .blue : .white.opacity(0.7))
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationRail()
        .environment(AppViewModel())
}