import Foundation
import Security

public enum KeychainError: Error {
    case status(OSStatus)
}

// env var first (for swift run), then keychain
public enum AnthropicAPIKey {
    private static let service = "com.flow.dictation.anthropic"
    private static let account = "api-key"

    public static func current() -> String? {
        if let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            let trimmed = env.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return storedKey()
    }

    public static var isConfigured: Bool { current() != nil }
    public static var hasStoredKey: Bool { storedKey() != nil }

    public static func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(trimmed.utf8)
        let update = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw KeychainError.status(update) }

        var add = baseQuery
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    public static func removeStoredKey() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func storedKey() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8)
        else { return nil }
        return key.isEmpty ? nil : key
    }
}
