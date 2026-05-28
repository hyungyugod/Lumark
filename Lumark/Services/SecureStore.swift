//
//  SecureStore.swift
//  Lumark
//
//  Keychain (kSecClassGenericPassword) 얇은 래퍼.
//  민감 값(API 키 등)은 UserDefaults 대신 여기로.
//

import Foundation
import Security

enum SecureStore {
    private static let service = "com.lumark.secure"

    /// 저장. 같은 key가 이미 있으면 덮어씀.
    @discardableResult
    static func save(_ value: String, key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let baseQuery: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key,
        ]
        SecItemDelete(baseQuery as CFDictionary)

        var addAttrs = baseQuery
        addAttrs[kSecValueData as String] = data
        addAttrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(addAttrs as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func load(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
