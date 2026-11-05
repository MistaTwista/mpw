# mpw for iOS

An iPhone app for the Master Password algorithm v3. It generates the same passwords as the
`mpw` CLI in this repository and shares its site list, `config.json`, through iCloud Drive.
The master password is typed on every unlock and never stored.

## Build

Requires Xcode 16 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
cd ios
xcodegen generate
open MPW.xcodeproj
```

`MPW.xcodeproj` is generated from `project.yml` and not committed: edit `project.yml`, then
run `xcodegen generate` again.

Without signing the app runs in the simulator and keeps its site list on the device.

## Run on an iPhone with iCloud sync

This needs a paid Apple Developer Program membership.

1. Copy `Config/Signing.local.xcconfig.example` to `Config/Signing.local.xcconfig` and set
   your `DEVELOPMENT_TEAM`. The file is not committed.
2. In the developer portal, create the iCloud container `iCloud.io.github.mistatwista.mpw`
   (or let Xcode create it on the first build).
3. `xcodegen generate`, then run on the device from Xcode.

The app stores `config.json` in its iCloud Drive folder, shown as "mpw" in Finder. Point the
CLI at it:

```sh
export MPW_CONFIG="$HOME/Library/Mobile Documents/iCloud~io~github~mistatwista~mpw/Documents/config.json"
```

## Tests

```sh
cd ios/MPWCore && swift test     # algorithm, shared vectors, config model (macOS)
cd ios && xcodebuild -project MPW.xcodeproj -scheme MPW \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test
```

## Layout

| Path | Contents |
|---|---|
| `MPWCore/Sources/CScrypt` | scrypt (RFC 7914) in C |
| `MPWCore/Sources/MPWCore` | algorithm, identicon, `config.json` model |
| `MPW` | SwiftUI app: unlock, site list, editor, session and config store |
| `MPWTests`, `MPWUITests` | app unit tests and a UI smoke test |
