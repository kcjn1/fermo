# FermoFilterExtension

This folder is the handoff point for the real macOS Network Extension target.

The Swift Package scaffold keeps the extension out of the build for now because the real content filter must be created and validated as an app extension in Xcode with the correct entitlements, signing, and user approval flow.

## Intended Target

- Type: Network Extension Content Filter.
- Data provider: evaluates network flows against active Fermo domain rules.
- Control provider: feeds rule snapshots from the app/helper into the data provider.

## Spike Domains

- `reddit.com`
- `youtube.com`

## Gate

Do not move Fermo to Toolary beta until this folder has been replaced by a signed and tested extension target.
