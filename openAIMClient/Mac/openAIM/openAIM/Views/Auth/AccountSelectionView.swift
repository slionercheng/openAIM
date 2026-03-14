//
//  AccountSelectionView.swift
//  openAIM
//
//  Created by Claude on 2026/3/9.
//

import SwiftUI

/// 账号选择视图
struct AccountSelectionView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Binding var showAccountSelection: Bool

    @State private var showSwitchError = false
    @State private var switchErrorMessage = ""
    @State private var isSwitching = false
    @State private var pendingAccount: SavedAccount?  // 切换失败的账号，用于跳转登录

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Account")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                Spacer()
            }
            .padding(20)
            .overlay(
                Rectangle()
                    .fill(Color(red: 0.886, green: 0.910, blue: 0.941))
                    .frame(height: 1),
                alignment: .bottom
            )

            // 账号列表
            if accounts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("No saved accounts")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)

                    Text("Sign in to add an account")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(accounts) { account in
                            AccountRowView(
                                account: account,
                                isSelected: appViewModel.authViewModel.currentUser?.id == account.id,
                                onSelect: {
                                    Task {
                                        await selectAccount(account)
                                    }
                                },
                                onRemove: {
                                    removeAccount(account)
                                }
                            )
                        }
                    }
                    .padding(16)
                }
            }

            // 底部提示
            if !accounts.isEmpty {
                VStack(spacing: 8) {
                    Text("Select an account to continue")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Text("Or sign in with a different account")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.white)
            }
        }
        .frame(width: 360, height: accounts.isEmpty ? 300 : 400)
        .background(Color(red: 0.945, green: 0.961, blue: 0.969))
        .alert("切换账号失败", isPresented: $showSwitchError) {
            Button("确定", role: .cancel) {
                // 用户确认后关闭 sheet 并跳转登录界面
                if let account = pendingAccount {
                    appViewModel.prefilledEmail = account.email
                    pendingAccount = nil
                }
                showAccountSelection = false
                appViewModel.currentView = .login
            }
        } message: {
            Text(switchErrorMessage)
        }
        .disabled(isSwitching)
        .overlay {
            if isSwitching {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView("切换中...")
                        .padding(20)
                        .background(.regularMaterial)
                        .cornerRadius(10)
                }
            }
        }
    }

    private var accounts: [SavedAccount] {
        AccountManager.shared.getSavedAccounts()
    }

    private func selectAccount(_ account: SavedAccount) async {
        // 如果点击的是当前已登录的账号，直接关闭选择界面
        if appViewModel.authViewModel.currentUser?.id == account.id {
            showAccountSelection = false
            return
        }

        isSwitching = true

        // 1. 先断开旧的 WebSocket 连接
        WebSocketService.shared.disconnect()
        logInfo("AccountSelection", "Disconnected WebSocket for account switch")

        // 2. 清除旧的用户状态
        appViewModel.authViewModel.clearAuthState()

        // 3. 通过 SessionManager 恢复会话（会自动切换工作区）
        let success = await AuthService.shared.restoreSession(from: account)

        if success {
            // 获取用户信息
            do {
                let user = try await AuthService.shared.getCurrentUser()
                await MainActor.run {
                    appViewModel.authViewModel.currentUser = user
                    appViewModel.authViewModel.state = .authenticated
                    appViewModel.currentView = .main
                    showAccountSelection = false
                    isSwitching = false
                    // 更新 Logger
                    Logger.shared.updateUser(userId: user.id, email: user.email)
                }
                // 加载初始数据
                await appViewModel.loadInitialData()
            } catch {
                // 获取用户信息失败
                await MainActor.run {
                    switchErrorMessage = "无法获取用户信息：\(error.localizedDescription)"
                    pendingAccount = account
                    showSwitchError = true
                    isSwitching = false
                }
            }
        } else {
            // Token 过期，显示错误提示
            await MainActor.run {
                switchErrorMessage = "账号 \"\(account.email)\" 登录已过期，请重新登录"
                pendingAccount = account
                showSwitchError = true
                isSwitching = false
            }
        }
    }

    private func removeAccount(_ account: SavedAccount) {
        AccountManager.shared.removeAccount(userId: account.id)

        // 如果删除的是当前登录的账号，登出
        if appViewModel.authViewModel.currentUser?.id == account.id {
            Task {
                await appViewModel.authViewModel.logout()
            }
        }
    }
}

// MARK: - Account Row View

struct AccountRowView: View {
    let account: SavedAccount
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                // 头像
                Circle()
                    .fill(avatarColor)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(avatarInitial)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                // 信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(red: 0.118, green: 0.161, blue: 0.231))

                    Text(account.email)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.392, green: 0.455, blue: 0.549))
                }

                Spacer()

                // 删除按钮
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            "Remove Account",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove \(account.displayName)", role: .destructive) {
                onRemove()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the account from this device. You can sign in again later.")
        }
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = (account.name ?? account.email).hashValue
        return colors[abs(hash) % colors.count]
    }

    private var avatarInitial: String {
        if let name = account.name, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return String(account.email.prefix(1)).uppercased()
    }
}

#Preview {
    AccountSelectionView(showAccountSelection: .constant(true))
        .environment(AppViewModel())
}