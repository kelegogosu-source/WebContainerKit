import Foundation

/// 网页入口及允许使用原生桥接的来源；只接受 HTTPS。
public struct WebContainerConfiguration {
    public let initialURL: URL
    public let allowedOrigins: Set<Origin>
    public var allowsInlineMediaPlayback: Bool = true
    /// 是否要求用户操作后才播放音频或视频；默认与原容器保持一致。
    public var mediaRequiresUserAction: Bool = false
    public var applicationNameForUserAgent: String?

    public struct Origin: Hashable {
        public let host: String
        public let port: Int

        public init?(url: URL) {
            guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased(),
                  !host.isEmpty, url.user == nil, url.password == nil else { return nil }
            self.host = host
            self.port = url.port ?? 443
        }
    }

    public init?(initialURL: URL, allowedOrigins: Set<Origin>? = nil) {
        guard let origin = Origin(url: initialURL) else { return nil }
        let origins = allowedOrigins ?? [origin]
        guard origins.contains(origin) else { return nil }
        self.initialURL = initialURL
        self.allowedOrigins = origins
    }

    func trusts(_ url: URL?) -> Bool {
        guard let url = url, let origin = Origin(url: url) else { return false }
        return allowedOrigins.contains(origin)
    }
}
