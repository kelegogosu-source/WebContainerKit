# Release checklist

Repository target: `kelegogosu-source/WebContainerKit`; intended initial tag: `0.1.0`.

1. Confirm the target repository name is available and the authenticated GitHub account can create it.
2. Review files, third-party rights, LICENSE, podspec metadata, and ensure no private configuration is included.
3. Create the public GitHub repository, commit and push the reviewed contents, and push the `0.1.0` tag.
4. Confirm the CocoaPods name is available and authenticate the CocoaPods Trunk session on this machine.
5. Run `pod spec lint WebContainerKit.podspec` against the public tag, then `pod trunk push WebContainerKit.podspec`.

Local `pod lib lint` checks local source, not the remote tag, and does not publish the pod. `pod trunk push` is a separate public release step.
