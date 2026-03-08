//
//  KeychainHelper.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation
import Security

/// Keychain 辅助类
class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    /// 保存数据
    func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // 先删除旧的
        SecItemDelete(query as CFDictionary)
        
        // 添加新的
        SecItemAdd(query as CFDictionary, nil)
    }
    
    /// 获取数据
    func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    /// 删除数据
    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    /// 清除所有数据
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}