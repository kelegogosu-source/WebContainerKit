import Foundation
import WebKit

/// 可注册同步与异步方法，兼容 DSBridge 的 iOS prompt 传输格式。
/// 业务能力由宿主显式注册；库不预置令牌、支付或归因接口。
@MainActor
public final class WebContainerBridge {
    public typealias SyncHandler = (Any?) -> Any?
    public typealias AsyncHandler = (Any?, @escaping (Any?) -> Void) -> Void
    private var syncHandlers: [String: SyncHandler] = [:]
    private var asyncHandlers: [String: AsyncHandler] = [:]
    weak var webView: WKWebView?
    var documentID = 0
    var trustedURL: ((URL?) -> Bool)?

    public init() {}

    /// 同名方法只能注册为同步或异步之一。保留的 `_dsb` 命名空间不能覆盖。
    public func register(_ name: String, handler: @escaping SyncHandler) {
        guard Self.validMethod(name) else { return }
        asyncHandlers.removeValue(forKey: name)
        syncHandlers[name] = handler
    }

    public func registerAsync(_ name: String, handler: @escaping AsyncHandler) {
        guard Self.validMethod(name) else { return }
        syncHandlers.removeValue(forKey: name)
        asyncHandlers[name] = handler
    }

    public func unregister(_ name: String) {
        syncHandlers.removeValue(forKey: name)
        asyncHandlers.removeValue(forKey: name)
    }

    private static func validMethod(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix("_dsb.")
    }

    func handle(method: String, payload: String?) -> String {
        let object = payload.flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any] ?? [:]
        let argument = object["data"] is NSNull ? nil : object["data"]
        if let callback = object["_dscbstub"] as? String {
            guard callback.range(of: "^dscb[0-9]+$", options: .regularExpression) != nil,
                  let handler = asyncHandlers[method] else { return response(code: -1, value: "") }
            let generation = documentID
            handler(argument) { [weak self] result in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.documentID == generation,
                          let webView = self.webView, self.trustedURL?(webView.url) == true,
                          let data = try? JSONSerialization.data(withJSONObject: [result ?? NSNull()]),
                          let json = String(data: data, encoding: .utf8) else { return }
                    webView.evaluateJavaScript("if(typeof window.\(callback)==='function'){window.\(callback)(\(json)[0]);delete window.\(callback);}", completionHandler: nil)
                }
            }
            return response(code: 0, value: "")
        }
        if method == "_dsb.hasNativeMethod", let query = argument as? [String: String] {
            let name = query["name"] ?? "", type = query["type"] ?? "all"
            let exists = (type != "asyn" && syncHandlers[name] != nil) || (type != "syn" && asyncHandlers[name] != nil)
            return response(code: 0, value: exists ? 1 : 0)
        }
        if ["_dsb.dsinit", "_dsb.returnValue", "_dsb.disableJavascriptDialogBlock"].contains(method) {
            return response(code: 0, value: "")
        }
        guard let handler = syncHandlers[method] else { return response(code: -1, value: "") }
        return response(code: 0, value: handler(argument) ?? "")
    }

    /// 调用网页通过 dsBridge.register 注册的方法；参数必须是 JSON 类型。
    public func callJavaScript(_ method: String, arguments: [Any] = []) {
        guard let webView = webView, trustedURL?(webView.url) == true,
              let argData = try? JSONSerialization.data(withJSONObject: arguments),
              let argJSON = String(data: argData, encoding: .utf8),
              let payload = try? JSONSerialization.data(withJSONObject: ["method": method, "callbackId": 0, "data": argJSON]),
              let json = String(data: payload, encoding: .utf8) else { return }
        webView.evaluateJavaScript("if(window._handleMessageFromNative)window._handleMessageFromNative(\(json));", completionHandler: nil)
    }

    private func response(code: Int, value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(["code": code, "data": value]),
              let data = try? JSONSerialization.data(withJSONObject: ["code": code, "data": value]),
              let json = String(data: data, encoding: .utf8) else { return "{\"code\":-1,\"data\":\"\"}" }
        return json
    }
}
