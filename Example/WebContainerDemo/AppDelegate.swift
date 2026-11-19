import UIKit
import WebContainerKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let config = WebContainerConfiguration(initialURL: URL(string: "https://example.com/")!)!
        let bridge = WebContainerBridge()
        bridge.register("hello") { _ in "Hello from iOS" }
        bridge.registerAsync("echo") { value, reply in reply(value) }
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = WebContainerViewController(configuration: config, bridge: bridge)
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
