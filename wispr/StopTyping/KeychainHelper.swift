//
//  KeychainHelper.swift
//  wispr
//
//  Thin wrapper around the macOS Keychain for storing
//  sensitive values like API keys.
//

import Foundation
import Security

nonisolated enum KeychainHelper: Sendable {

    /// Saves a string value to the Keychain under the given key.
    /// Overwrites any existing value for that key.
    static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add the new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Loads a string value from the Keychain for the given key.
    /// Returns nil if no value is stored.
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Deletes a value from the Keychain for the given key.
    static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: - Known Keys

    static let groqAPIKey = "com.stopTyping.groqAPIKey"

    // MARK: - Hardcoded Pro API Key

    /// Seeds the Groq API key into the Keychain if not already present.
    /// Reads from the GROQ_API_KEY environment variable or a bundled config.
    /// Called from the app on launch so the key is written by the app itself,
    /// which grants automatic Keychain access with no user prompt.
    static func seedGroqKeyIfNeeded() {
        // Only seed if no key exists yet
        guard load(key: groqAPIKey) == nil else { return }

        // Try environment variable first (set in Xcode scheme or shell)
        if let envKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"], !envKey.isEmpty {
            try? save(key: groqAPIKey, value: envKey)
            return
        }

        // Try bundled Secrets.plist (not committed to git)
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url),
           let key = dict["GROQ_API_KEY"] as? String, !key.isEmpty {
            try? save(key: groqAPIKey, value: key)
        }
    }

    // MARK: - Errors

    enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)
        case deleteFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Keychain save failed (OSStatus \(status))"
            case .deleteFailed(let status):
                return "Keychain delete failed (OSStatus \(status))"
            }
        }
    }
}
