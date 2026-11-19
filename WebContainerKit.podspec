Pod::Spec.new do |s|
  s.name             = 'WebContainerKit'
  s.version          = '0.1.0'
  s.summary          = 'Reusable WKWebView container with an explicit JavaScript bridge.'
  s.description      = 'A small HTTPS-only WKWebView container, DSBridge-compatible prompt transport, and optional Keychain and AES-GCM helpers.'
  s.homepage         = 'https://github.com/kelegogosu-source/WebContainerKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'kelegogosu-source' => '269182031+kelegogosu-source@users.noreply.github.com' }
  s.source           = { :git => 'https://github.com/kelegogosu-source/WebContainerKit.git', :tag => s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.swift_version    = '5.0'
  s.source_files     = 'Sources/WebContainerKit/**/*.swift'
  s.frameworks       = 'UIKit', 'WebKit', 'Security'
end
