# iOS app design

Date: 2026-11-05
Status: approved design; plan in docs/superpowers/plans/2026-11-05-ios-app.md

## Goal

A native iOS app that generates Master Password (algorithm v3) site passwords, identical to the
Go CLI in this repository, and shares the CLI's site list through iCloud Drive.

Why not use Spectre (the algorithm author's app): we want one site list shared with the CLI on
the Mac, and a small codebase we maintain ourselves.

## Decisions

| Topic | Decision |
|---|---|
| Platforms | iPhone only, iOS 17+. Runs on iPad in iPhone mode. |
| Language / UI | Swift, SwiftUI, Observation. No third-party UI libraries. |
| Location | `ios/` in this repository, next to the Go CLI. |
| Project file | XcodeGen: `ios/project.yml` is committed, `.xcodeproj` is generated and ignored. |
| Master password | Typed on every unlock. Neither the password nor the master key is ever persisted. |
| AutoFill | Not in v1. The algorithm lives in a separate package so an extension can be added later. |
| Config sharing | `config.json` in the app's iCloud container; the CLI finds it through `MPW_CONFIG`. |
| scrypt | Small C target written from RFC 7914: the RFC's Salsa20/8 reference code plus PBKDF2-HMAC-SHA256 from CommonCrypto. No third-party code. |
| UI language | English. Localization is out of scope for v1. |
| Apple account | Paid Developer Program will be obtained; until then the app runs with a local config. |
| Identifiers | Bundle id `io.github.mistatwista.mpw`, iCloud container `iCloud.io.github.mistatwista.mpw`. Can be changed before the first App Store upload. |

## Repository layout

```
cmd/, internal/            Go CLI (existing)
internal/mpw/testdata/
  testcases.xml            reference vectors (existing), shared by Go and Swift tests
  golden.json              144 regression vectors, moved out of mpw_test.go, shared
ios/
  project.yml              XcodeGen project: app target, unit tests, UI tests
  MPW/                     app sources (SwiftUI)
  MPWTests/                app unit tests
  MPWUITests/              one smoke UI test
  MPWCore/                 Swift package, no UI, builds for iOS and macOS
    Package.swift
    Sources/CScrypt/       scrypt (C) from RFC 7914
    Sources/MPWCore/       algorithm and config model
    Tests/MPWCoreTests/    reads internal/mpw/testdata/* from the repository
```

## MPWCore

Mirrors the Go package `internal/mpw` one to one, so the two implementations are easy to compare.

- `masterKey(fullName:masterPassword:) throws -> MasterKey` — scrypt, N=32768, r=8, p=2, 64 bytes,
  salt `"com.lyndir.masterpassword" . UInt32BE(len(name)) . name`. Lengths are UTF-8 byte counts.
- `siteKey(masterKey:siteName:counter:) -> Data` — HMAC-SHA256 (CryptoKit) over
  `scope . UInt32BE(len(site)) . site . UInt32BE(counter)`.
- `sitePassword(siteKey:type:) throws -> String` — template chosen by `siteKey[0]`, characters
  by `siteKey[i+1]`, same template and character tables as `internal/mpw/templates.go`.
- `ResultType` — the 8 types with the same names and one-letter abbreviations as the CLI,
  parsed case-insensitively.
- `Identicon(fullName:masterPassword:)` — text and color index 1…7, same tables as Go,
  including the `☄` accessory.
- `MasterKey` is a final class wrapping the 64 bytes. It is held only in memory; when the session
  ends the owning object drops it and zeroes its buffer on a best-effort basis (Swift may have
  made copies, so this is hygiene, not a guarantee).

scrypt runs off the main actor (`Task.detached`) because it takes a noticeable fraction of a second.

### Config model

`Config` is the same JSON the CLI reads:

```json
{
  "FULL_NAME": "Robert Lee Mitchell",
  "sites": [
    {"name": "github.com", "counter": 2, "type": "Long"}
  ]
}
```

- `type` is new and optional; missing means Long. Values use the CLI names (`Maximum`, `Long`, …).
- A missing or zero `counter` means 1, as in the CLI.
- Unknown keys, at the top level and inside sites, are kept and written back unchanged, so the
  app never drops data that a newer CLI adds.
- Output is pretty-printed with stable key order so diffs stay readable.

## Go CLI changes (same branch)

- `MPW_CONFIG` environment variable: an explicit config path. It wins over
  `$XDG_CONFIG_HOME/config.json` and `~/.config/mpw/config.json`.
- Site `type` from the config: priority is Long < site `type` in config < `-t`. An unknown type
  in the config is an error that names the site.
- `golden.json` replaces the inline regression table in `internal/mpw/mpw_test.go`.
- README documents `MPW_CONFIG`, the `type` field, and the iCloud path on macOS:
  `~/Library/Mobile Documents/iCloud~io~github~mistatwista~mpw/Documents/config.json`
  (the container id with `.` replaced by `~`).

## Screens

### Unlock

- Full name field, prefilled from `FULL_NAME`. When the config has no name, a "Remember name"
  toggle (on by default) saves the typed name after a successful unlock.
- Master password field (secure).
- Identicon under the fields, recomputed as the user types (one HMAC, cheap). It lets the user
  spot a typo before generating anything.
- "Unlock" derives the master key in the background with a progress indicator, then shows the
  site list.

### Site list

- Sites from the config, sorted by name, with a search field. Each row shows name, type and
  counter.
- Tapping a site shows its password masked, with "Show" and "Copy".
- When the search text matches no site, two extra rows appear: "Password for «text»" (generate
  once with counter 1 and type Long, not saved) and "Add «text»" (opens the editor prefilled).
- Swipe to delete a site.
- A lock button ends the session.

### Site editor

- Name, counter (stepper, 1…UInt32.max), type (picker of the 8 types).
- Saving writes the config. Names must be non-empty and unique.

## Session and clipboard

- The master key exists only between unlock and lock.
- Lock immediately when the device locks (`protectedDataWillBecomeUnavailable`).
- When the app goes to the background, remember the time. On return, lock if more than
  2 minutes passed. The timeout is a constant, not a setting.
- Lock button locks immediately.
- While the app is inactive or in the background, a privacy cover hides the content, so the app
  switcher snapshot shows no passwords.
- Copy puts the password on the pasteboard with `localOnly` (no Universal Clipboard to the Mac)
  and a 60-second expiration.

The lock rules live in a small `Session` type with an injected clock so they can be unit tested.

## Config storage

`ConfigStore` (`@Observable`, main actor) owns the config file.

- Location: `Documents/config.json` in the app's iCloud ubiquity container. `Info.plist` declares
  the container in `NSUbiquitousContainers` with `NSUbiquitousContainerIsDocumentScopePublic`, so
  the folder is visible in iCloud Drive and Finder as "mpw". If iCloud is not
  available (no account, or no entitlement before the paid account exists), it falls back to
  the app's local Documents folder and the UI shows a "Sync is off" banner.
- Reads and writes go through `NSFileCoordinator`. `ConfigStore` is an `NSFilePresenter`, so edits
  made on the Mac (by hand or by the CLI) are picked up and the list refreshes.
- On first launch with no file, it creates nothing until the user saves a site or a name.
- Conflicts: last writer wins. The file is small and edited by one person.
- Invalid JSON: show the error, keep the file untouched, and make the list read-only until the
  file parses again. This matches the CLI, which refuses to run with a broken config.
- A site with an unknown `type` is shown with an error badge and cannot generate; other sites
  work.

## Testing

MPWCore, with `swift test` (runs on macOS, no simulator needed). The shared files live outside
the package, which SwiftPM cannot bundle as resources, so the tests locate the repository root
from `#filePath` and read `internal/mpw/testdata/` directly. These tests therefore run with
`swift test` on macOS only, not inside the iOS app's test bundle.

- scrypt against the fast RFC 7914 vectors (the N = 1048576 vector is skipped).
- `testcases.xml`: algorithm 3, Authentication purpose, no key context — the same filter as the
  Go test. Passwords and identicons must match.
- `golden.json`: all 144 vectors.
- Config: decode a file written by the CLI; round-trip keeps unknown keys; missing counter and
  type use defaults; invalid JSON throws.

App unit tests:

- `ConfigStore` on a temporary directory: load, save, read-only mode on invalid JSON, recovery
  once the file is fixed. The iCloud container lookup is injected so tests use a plain folder.
- `Session`: key kept at 1:59 in background, dropped at 2:01, dropped at once on device lock and
  on the lock button.

UI test: one smoke test — unlock with the reference vector name and password, find
`masterpasswordapp.com`, check the shown password is `Jejr5[RepuSosp`.

Go: tests for `MPW_CONFIG` and for `type` priority.

CI (GitHub Actions): the existing Go job stays. A new macOS job runs `swift test` in
`ios/MPWCore`, then `xcodegen generate` and builds the app and runs unit tests on an iOS
simulator. Signing is disabled in CI.

Manual check once the paid account exists: install on an iPhone, edit `config.json` on the Mac
through the CLI and in Finder, confirm the app picks up the change and that its edits reach the
Mac.

## Out of scope for v1

AutoFill extension, storing the master key (Keychain / Face ID), import from Spectre, iPad
layout, macOS app, login names and recovery answers (other key purposes), algorithm versions
other than 3.
