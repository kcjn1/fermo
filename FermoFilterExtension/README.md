# FermoFilterExtension

This folder now contains the macOS Network Extension content-filter provider used by the Xcode spike.

It is intentionally outside `Package.swift`. The Swift Package remains the testable model layer; the real content filter is built through `Fermo.xcodeproj` because macOS requires entitlements, signing, an embedded system extension, and user approval.

## Target

- Product type: macOS System Extension.
- Provider type: Network Extension `com.apple.networkextension.filter-data`.
- Data provider: `FermoFilterDataProvider`.
- Rule input: `FermoCore.ContentFilterRuleSnapshot` JSON in the shared app group.

## Spike Domains

- `reddit.com`
- `youtube.com`

The debug provider falls back to a one-hour reddit/youtube spike snapshot if no app-group snapshot exists. Release builds allow all traffic when no snapshot exists.

## Gate

Do not move Fermo to Toolary beta until this target has passed signed-build validation across Safari, Chrome, Firefox, private windows, sleep/wake, Wi-Fi changes, and reboot.
