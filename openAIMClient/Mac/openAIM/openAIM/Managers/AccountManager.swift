//
//  AccountManager.swift
//  openAIM
//
//  Created by Claude on 2026/3/9.
//

import Foundation

/// 保存的账号信息
struct SavedAccount: Codable, Identifiable, Hashable {
    let id: String           // 用户 ID
    let email: String
    let name: String?
    let avatar: String?
    let accessToken: String
    let refreshToken: String
    let lastLoginAt: Date

    var displayName: String {
        name ?? email
    }
}

/// 账号管理器
class AccountManager {
    static let shared = AccountManager()

    private let savedAccountsKey = "openaim_saved_accounts"
    private let currentAccountIdKey = "openaim_current_account_id"

    private init() {}

    // MARK: - Public Methods

    /// 获取所有已保存的账号
    func getSavedAccounts() -> [SavedAccount] {
        guard let data = UserDefaults.standard.data(forKey: savedAccountsKey),
              let accounts = try? JSONDecoder().decode([SavedAccount].self, from: data) else {
            return []
        }
        return accounts.sorted { $0.lastLoginAt > $1.lastLoginAt }
    }

    /// 保存账号
    func saveAccount(userId: String, email: String, name: String?, avatar: String?, accessToken: String, refreshToken: String) {
        var accounts = getSavedAccounts()

        // 移除已存在的同名账号
        accounts.removeAll { $0.id == userId }

        // 添加新账号
        let newAccount = SavedAccount(
            id: userId,
            email: email,
            name: name,
            avatar: avatar,
            accessToken: accessToken,
            refreshToken: refreshToken,
            lastLoginAt: Date()
        )
        accounts.append(newAccount)

        // 保存到 UserDefaults
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: savedAccountsKey)
        }

        // 设置为当前账号
        setCurrentAccountId(userId)
    }

    /// 获取当前账号 ID
    func getCurrentAccountId() -> String? {
        return UserDefaults.standard.string(forKey: currentAccountIdKey)
    }

    /// 设置当前账号 ID
    func setCurrentAccountId(_ id: String) {
        UserDefaults.standard.set(id, forKey: currentAccountIdKey)
    }

    /// 获取指定账号
    func getAccount(userId: String) -> SavedAccount? {
        return getSavedAccounts().first { $0.id == userId }
    }

    /// 获取当前账号
    func getCurrentAccount() -> SavedAccount? {
        guard let currentId = getCurrentAccountId() else {
            return getSavedAccounts().first
        }
        return getAccount(userId: currentId)
    }

    /// 删除账号
    func removeAccount(userId: String) {
        var accounts = getSavedAccounts()
        accounts.removeAll { $0.id == userId }

        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: savedAccountsKey)
        }

        // 如果删除的是当前账号，清除当前账号 ID
        if getCurrentAccountId() == userId {
            UserDefaults.standard.removeObject(forKey: currentAccountIdKey)
        }
    }

    /// 更新账号的 token
    func updateTokens(userId: String, accessToken: String, refreshToken: String) {
        var accounts = getSavedAccounts()

        if let index = accounts.firstIndex(where: { $0.id == userId }) {
            let old = accounts[index]
            accounts[index] = SavedAccount(
                id: old.id,
                email: old.email,
                name: old.name,
                avatar: old.avatar,
                accessToken: accessToken,
                refreshToken: refreshToken,
                lastLoginAt: Date()
            )

            if let data = try? JSONEncoder().encode(accounts) {
                UserDefaults.standard.set(data, forKey: savedAccountsKey)
            }
        }
    }

    /// 检查账号是否已保存
    func isAccountExists(userId: String) -> Bool {
        return getSavedAccounts().contains { $0.id == userId }
    }

    /// 检查邮箱是否已登录
    func isEmailLoggedIn(_ email: String) -> SavedAccount? {
        return getSavedAccounts().first { $0.email.lowercased() == email.lowercased() }
    }

    /// 清除所有账号
    func clearAllAccounts() {
        UserDefaults.standard.removeObject(forKey: savedAccountsKey)
        UserDefaults.standard.removeObject(forKey: currentAccountIdKey)
    }
}