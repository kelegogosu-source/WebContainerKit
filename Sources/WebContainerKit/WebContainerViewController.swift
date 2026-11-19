import UIKit
import WebKit

/// 可嵌入导航栈或作为子控制器的网页容器。
@MainActor
public final class WebContainerViewController: UIViewController {
    public let configuration: WebContainerConfiguration
    public let bridge: WebContainerBridge
    public private(set) var webView: WKWebView!
    public var onLoadError: ((Error) -> Void)?
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let retryButton = UIButton(type: .system)
    private var lastRequest: URLRequest?

    public init(configuration: WebContainerConfiguration, bridge: WebContainerBridge? = nil) {
        self.configuration = configuration
        self.bridge = bridge ?? WebContainerBridge()
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(configuration:bridge:)") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = configuration.allowsInlineMediaPlayback
        config.mediaTypesRequiringUserActionForPlayback = configuration.mediaRequiresUserAction ? [.audio, .video] : []
        config.applicationNameForUserAgent = configuration.applicationNameForUserAgent
        config.userContentController.addUserScript(WKUserScript(source: "window._dswk=true;", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        bridge.webView = webView
        bridge.trustedURL = { [configuration] url in configuration.trusts(url) }
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.hidesWhenStopped = true
        view.addSubview(loadingView)
        retryButton.setTitle("Reload", for: .normal)
        retryButton.addTarget(self, action: #selector(reloadPage), for: .touchUpInside)
        retryButton.isHidden = true
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(retryButton)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor), webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor), webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor), loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor), retryButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        let request = URLRequest(url: configuration.initialURL)
        lastRequest = request
        webView.load(request)
    }

    public func reload() { webView?.reload() }
    @objc private func reloadPage() {
        if let request = lastRequest { webView.load(request) }
        else { reload() }
    }
}

extension WebContainerViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        bridge.documentID += 1
        retryButton.isHidden = true
        loadingView.startAnimating()
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loadingView.stopAnimating() }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(error) }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(error) }

    private func finish(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        loadingView.stopAnimating()
        retryButton.isHidden = false
        onLoadError?(error)
    }

    public func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if response.isForMainFrame, let http = response.response as? HTTPURLResponse, http.statusCode >= 400 {
            decisionHandler(.cancel)
            finish(NSError(domain: "WebContainerKit.HTTP", code: http.statusCode))
        } else { decisionHandler(.allow) }
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish(NSError(domain: "WebContainerKit.WebContent", code: 1))
    }

    public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, configuration.trusts(url) else { decisionHandler(.cancel); return }
        if action.targetFrame?.isMainFrame == true { lastRequest = action.request }
        decisionHandler(.allow)
    }
}

extension WebContainerViewController: WKUIDelegate {
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                        for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil, self.configuration.trusts(action.request.url) { webView.load(action.request) }
        return nil
    }

    public func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                        defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                        completionHandler: @escaping (String?) -> Void) {
        if prompt.hasPrefix("_dsbridge=") {
            let origin = frame.securityOrigin
            let trusted = self.configuration.allowedOrigins.contains {
                $0.host == origin.host.lowercased() && $0.port == (origin.port == 0 ? 443 : origin.port)
            }
            guard frame.isMainFrame, origin.protocol.lowercased() == "https", trusted else { completionHandler(nil); return }
            completionHandler(bridge.handle(method: String(prompt.dropFirst("_dsbridge=".count)), payload: defaultText))
            return
        }
        let alert = UIAlertController(title: prompt, message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(alert.textFields?.first?.text) })
        present(alert, animated: true)
    }

    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                        initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                        initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}
