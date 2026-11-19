import Foundation

/// 可逆字符串混淆仅用于降低静态文本的可读性，不具备加密或保密能力。
public enum WebContainerObfuscation {
    public enum ObfuscationError: Error { case emptyMask, invalidUTF8 }

    public static func encode(_ text: String, mask: [UInt8]) throws -> [UInt8] {
        guard !mask.isEmpty else { throw ObfuscationError.emptyMask }
        return text.utf8.enumerated().map { $0.element ^ mask[$0.offset % mask.count] }
    }

    public static func decode(_ bytes: [UInt8], mask: [UInt8]) throws -> String {
        guard !mask.isEmpty else { throw ObfuscationError.emptyMask }
        let decoded = bytes.enumerated().map { $0.element ^ mask[$0.offset % mask.count] }
        guard let value = String(bytes: decoded, encoding: .utf8) else { throw ObfuscationError.invalidUTF8 }
        return value
    }
}
