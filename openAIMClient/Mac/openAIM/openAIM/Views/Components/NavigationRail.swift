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

    @State private var showUserMenu = false

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
                badge: appViewModel.conversationViewModel.totalUnreadCount,
                action: { appViewModel.currentView = .main }
            )

            // Contacts
            navButton(
                icon: "person.2.fill",
                isActive: appViewModel.currentView == .contacts,
                badge: appViewModel.friendshipViewModel.totalPendingCount,
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

            // User Avatar Button
            Button {
                showUserMenu.toggle()
            } label: {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(appViewModel.authViewModel.currentUser?.name?.prefix(1) ?? "U")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showUserMenu, arrowEdge: .leading) {
                UserMenuView(
                    showAccountSelection: Binding(
                        get: { appViewModel.showAccountSelection },
                        set: { appViewModel.showAccountSelection = $0 }
                    ),
                    showUserMenu: $showUserMenu
                )
                .environment(appViewModel)
            }
        }
        .padding(.vertical, 12)
        .frame(width: 64)
        .background(Color(red: 0.118, green: 0.161, blue: 0.231))
        .sheet(isPresented: Binding(
            get: { appViewModel.showAccountSelection },
            set: { appViewModel.showAccountSelection = $0 }
        )) {
            AccountSelectionView(showAccountSelection: Binding(
                get: { appViewModel.showAccountSelection },
                set: { appViewModel.showAccountSelection = $0 }
            ))
                .environment(appViewModel)
        }
    }

    private var avatarColor: Color {
        guard let name = appViewModel.authViewModel.currentUser?.name else {
            return .gray
        }
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = name.hashValue
        return colors[abs(hash) % colors.count]
    }

    private func navButton(icon: String, isActive: Bool, badge: Int = 0, action: @escaping () -> Void) -> some View {
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
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Text(badge > 99 ? "99+" : "\(badge)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationRail()
        .environment(AppViewModel())
}

// MARK: - User Menu View (Popover)

struct UserMenuView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Binding var showAccountSelection: Bool
    @Binding var showUserMenu: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 用户信息头部
            HStack(spacing: 12) {
                // 头像
                Circle()
                    .fill(avatarColor)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(appViewModel.authViewModel.currentUser?.name?.prefix(1) ?? "U")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(appViewModel.authViewModel.currentUser?.name ?? "User")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                    Text(appViewModel.authViewModel.currentUser?.email ?? "")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                        .lineLimit(1)
                }
            }
            .padding(16)

            Divider()

            // 快捷操作区域
            VStack(spacing: 0) {
                // 未读消息
                if appViewModel.conversationViewModel.totalUnreadCount > 0 {
                    menuButton(
                        icon: "message.badge.fill",
                        title: "Messages",
                        badge: appViewModel.conversationViewModel.totalUnreadCount,
                        action: {
                            showUserMenu = false
                            appViewModel.currentView = .main
                        }
                    )
                    // 清除所有未读按钮
                    Button {
                        appViewModel.conversationViewModel.clearAllUnreadCounts()
                        showUserMenu = false
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.green)
                                .frame(width: 20)

                            Text("Mark all as read")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(Color.white)
                    Divider().padding(.leading, 44)
                }

                // 好友请求
                if appViewModel.friendshipViewModel.totalPendingCount > 0 {
                    menuButton(
                        icon: "person.badge.plus",
                        title: "Friend Requests",
                        badge: appViewModel.friendshipViewModel.totalPendingCount,
                        action: {
                            showUserMenu = false
                            appViewModel.currentView = .contacts
                        }
                    )
                    Divider().padding(.leading, 44)
                }

                // Switch Account
                menuButton(
                    icon: "arrow.left.arrow.right",
                    title: "Switch Account",
                    badge: nil,
                    action: {
                        showUserMenu = false
                        showAccountSelection = true
                    }
                )

                Divider().padding(.leading, 44)

                // Logout
                menuButton(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Log Out",
                    badge: nil,
                    isDestructive: true,
                    action: {
                        showUserMenu = false
                        Task {
                            await appViewModel.authViewModel.logout()
                            appViewModel.currentView = .login
                        }
                    }
                )
            }
        }
        .frame(width: 260)
    }

    private func menuButton(icon: String, title: String, badge: Int?, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isDestructive ? .red : Color(red: 0.392, green: 0.455, blue: 0.549))
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(isDestructive ? .red : Color(red: 0.118, green: 0.161, blue: 0.231))

                Spacer()

                if let badge = badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(Color.white)
    }

    private var avatarColor: Color {
        guard let name = appViewModel.authViewModel.currentUser?.name else {
            return .gray
        }
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = name.hashValue
        return colors[abs(hash) % colors.count]
    }
}