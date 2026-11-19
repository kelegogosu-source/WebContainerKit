# WebContainerKit

一个可复用的 iOS WKWebView 容器，提供来源限制、DSBridge 风格的同步／异步 prompt 桥接，以及独立的 Keychain 和 AES-GCM 工具。最低 iOS 15，Swift 5。业务登录、支付、Adjust、服务端域名和凭据由宿主自行提供。

## 安装

在 Podfile 中添加：

```ruby
pod 'WebContainerKit', '~> 0.1.0'
```

也可直接从仓库安装，不依赖 Trunk 的目录索引：

```ruby
pod 'WebContainerKit', :git => 'https://github.com/kelegogosu-source/WebContainerKit.git', :tag => '0.1.0'
```

CocoaPods 官方计划于 2026 年 12 月 2 日将 Trunk 设为只读（[官方计划](https://blog.cocoapods.org/CocoaPods-Specs-Repo/)），具体状态以官方公告为准。上面的 Git 方式在 Trunk 不可写时仍可作为安装方式。

本地开发可使用 `pod 'WebContainerKit', :path => '/path/to/WebContainerKit'`。仓库中的示例使用相对路径：

```sh
cd Example
pod install
open WebContainerDemo.xcworkspace
```

## 网页和桥接

```swift
import WebContainerKit

let config = WebContainerConfiguration(initialURL: URL(string: "https://example.com/")!)!
let bridge = WebContainerBridge()
bridge.register("hello") { argument in
    return ["message": "hello"]
}
bridge.registerAsync("echo") { argument, reply in
    reply(argument)
}
let controller = WebContainerViewController(configuration: config, bridge: bridge)
navigationController?.pushViewController(controller, animated: true)
```

网页需要自行引入兼容 DSBridge v3 的 JavaScript 库，例如调用 `dsBridge.call('hello', {})` 或 `dsBridge.call('echo', value, callback)`。原生可使用 `bridge.callJavaScript("method", arguments: [...])` 调用网页注册的方法。

默认只允许入口的 HTTPS 来源导航和调用桥接；若需要其他来源，请显式创建 `WebContainerConfiguration.Origin` 加入 `allowedOrigins`。加载失败时显示 Reload 并调用 `onLoadError`。桥接支持注册、移除、存在性查询和一次性异步回调；并未实现 DSBridge 的全部功能，例如原生调用 JS 后获取返回值、进度回调和页面关闭协议。不要把不可信内容加入桥接允许列表。

## 存储和加密

```swift
let store = WebContainerSecureStore(service: "com.example.app.credentials")
try store.write(Data(token.utf8), account: "session")
let saved = try store.read("session")
try store.delete("session")

// key 由宿主使用安全随机数生成，并安全保存；长度须为 16、24 或 32 字节。
let encrypted = try WebContainerCrypto.seal(plaintext, key: key)
let original = try WebContainerCrypto.open(encrypted, key: key)
```

Keychain 项使用 `AfterFirstUnlockThisDeviceOnly`；恢复到另一台设备时不能依靠原 Keychain 项解密。AES-GCM 会检测密文被修改。密钥丢失后无法恢复密文，宿主需设计备份及轮换策略。不要把真实密钥、Token 或服务端凭据提交到仓库，也不要将固定解密密钥打进应用。`WebContainerObfuscation.encode` / `decode` 提供可逆的轻量字符串混淆，适合降低非敏感静态文本的可读性；公开源码或客户端中的字符串混淆不能提供保密性，本库不声称能隐藏客户端秘密。

## 测试

```sh
cd Example
pod install
xcodebuild -workspace WebContainerDemo.xcworkspace -scheme WebContainerDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

测试包含来源检查、桥接注册、AES-GCM 篡改检测及 Keychain 读写。Keychain 测试需要测试宿主具备可用的签名和 Keychain 权限。

## 许可

MIT，详见 [LICENSE](LICENSE)。
