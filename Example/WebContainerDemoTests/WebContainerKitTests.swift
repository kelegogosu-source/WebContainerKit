import XCTest
@testable import WebContainerKit

final class WebContainerKitTests: XCTestCase {
    func testOriginRequiresHTTPSAndMatchingPort() {
        let url = URL(string: "https://example.com/path")!
        let config = WebContainerConfiguration(initialURL: url)!
        XCTAssertTrue(config.trusts(URL(string: "https://example.com/other")))
        XCTAssertFalse(config.trusts(URL(string: "http://example.com/")))
        XCTAssertFalse(config.trusts(URL(string: "https://evil-example.com/")))
        XCTAssertFalse(config.trusts(URL(string: "https://example.com:444/")))
        XCTAssertNil(WebContainerConfiguration(initialURL: URL(string: "https://user:pass@example.com")!))
    }

    @MainActor func testBridgeRegistrationAndReservedMethods() throws {
        let bridge = WebContainerBridge()
        bridge.register("echo") { $0 }
        func parse(_ value: String) throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
        }
        let response = try parse(bridge.handle(method: "echo", payload: #"{"data":"hello"}"#))
        XCTAssertEqual(response["data"] as? String, "hello")
        bridge.unregister("echo")
        XCTAssertEqual(try parse(bridge.handle(method: "echo", payload: nil))["code"] as? Int, -1)
        bridge.registerAsync("async") { _, done in done(true) }
        XCTAssertEqual(try parse(bridge.handle(method: "async", payload: #"{"_dscbstub":"evil();"}"#))["code"] as? Int, -1)
    }

    func testCryptoRejectsTamperingAndInvalidKey() throws {
        let key = Data(repeating: 42, count: 32)
        let message = Data("private data".utf8)
        let cipher = try WebContainerCrypto.seal(message, key: key)
        XCTAssertEqual(try WebContainerCrypto.open(cipher, key: key), message)
        var modified = cipher
        modified[modified.startIndex] ^= 1
        XCTAssertThrowsError(try WebContainerCrypto.open(modified, key: key))
        XCTAssertThrowsError(try WebContainerCrypto.seal(message, key: Data()))
    }

    func testObfuscationRoundTrip() throws {
        let bytes = try WebContainerObfuscation.encode("配置 Value", mask: [17, 42])
        XCTAssertEqual(try WebContainerObfuscation.decode(bytes, mask: [17, 42]), "配置 Value")
        XCTAssertThrowsError(try WebContainerObfuscation.decode(bytes, mask: []))
    }

    func testKeychainStoreWriteUpdateAndDelete() throws {
        let store = WebContainerSecureStore(service: "webcontainer.tests." + UUID().uuidString)
        defer { try? store.delete("token") }
        XCTAssertNil(try store.read("token"))
        try store.write(Data("one".utf8), account: "token")
        try store.write(Data("two".utf8), account: "token")
        XCTAssertEqual(try store.read("token"), Data("two".utf8))
        try store.delete("token")
        XCTAssertNil(try store.read("token"))
    }
}
