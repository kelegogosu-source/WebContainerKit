import Foundation
import Security
import CryptoKit

/// 使用 Keychain 存储数据；名称和 service 由宿主决定。
public struct WebContainerSecureStore {
    public enum StoreError: Error { case keychain(OSStatus), invalidData }
    private let service: String

    public init(service: String) {
        precondition(!service.isEmpty, "Keychain service must not be empty")
        self.service = service
    }

    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    public func read(_ account: String) throws -> Data? {
        var request = query(account)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw StoreError.keychain(status) }
        guard let data = value as? Data else { throw StoreError.invalidData }
        return data
    }

    public func write(_ data: Data, account: String) throws {
        let status = SecItemUpdate(query(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw StoreError.keychain(status) }
        var attributes = query(account)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let created = SecItemAdd(attributes as CFDictionary, nil)
        if created == errSecDuplicateItem {
            let retry = SecItemUpdate(query(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard retry == errSecSuccess else { throw StoreError.keychain(retry) }
        } else if created != errSecSuccess { throw StoreError.keychain(created) }
    }

    public func delete(_ account: String) throws {
        let status = SecItemDelete(query(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw StoreError.keychain(status) }
    }
}

/// AES-GCM 对任意数据进行认证加密。密钥必须由宿主安全生成和保管。
public enum WebContainerCrypto {
    public enum CryptoError: Error { case invalidKey, invalidCiphertext }

    public static func seal(_ plaintext: Data, key: Data) throws -> Data {
        guard [16, 24, 32].contains(key.count) else { throw CryptoError.invalidKey }
        guard let combined = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key)).combined else { throw CryptoError.invalidCiphertext }
        return combined
    }

    public static func open(_ ciphertext: Data, key: Data) throws -> Data {
        guard [16, 24, 32].contains(key.count) else { throw CryptoError.invalidKey }
        return try AES.GCM.open(AES.GCM.SealedBox(combined: ciphertext), using: SymmetricKey(data: key))
    }
}
