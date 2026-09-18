# Harmony

SwiftUI multiplatform app (iOS, iPadOS, macOS) built with Xcode 27.
At present the project is essentially the Xcode template — treat any
convention below as a starting point, not as settled architecture.

## Layout

```
Harmony.xcodeproj      single target and scheme, both named "Harmony"
MyApp/                 all source lives here
  MyApp.swift          @main entry point, WindowGroup
  ContentView.swift    root view
  Assets.xcassets/
```

The source directory is named `MyApp/` while the target is named `Harmony`.
This is a leftover from the template. Renaming the directory requires
updating the file references in `project.pbxproj`, so do not rename it as a
drive-by change.

## Build

```bash
xcodebuild -project Harmony.xcodeproj -scheme Harmony -destination 'platform=macOS' build
```

Swap the destination for iOS. Prefer the generic destination, which does not
depend on which simulators happen to be installed:

```bash
xcodebuild -project Harmony.xcodeproj -scheme Harmony -destination 'generic/platform=iOS Simulator' build
```

To build for one concrete device, pass `-destination 'platform=iOS Simulator,name=iPhone 18 Pro'`.
Device names shift between Xcode releases, so check `xcrun simctl list devices available`
before hardcoding one.

There is **no test target**. Do not invent `xcodebuild test` invocations
until one exists.

### If xcodebuild cannot find Xcode

`xcode-select` on this machine points at the Command Line Tools, which makes
every `xcodebuild` call fail with:

```
tool 'xcodebuild' requires Xcode, but active developer directory
'/Library/Developer/CommandLineTools' is a command line tools instance
```

Prefix the command instead of changing the setting system-wide:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ...
```

The permanent fix is `sudo xcode-select -s /Applications/Xcode.app`, which
needs a password and is therefore the user's call, not an agent's.

## Build settings

| Setting | Value |
| --- | --- |
| Bundle identifier | `de.superook.Harmony` |
| Supported platforms | `iphoneos iphonesimulator macosx` |
| `SDKROOT` | `auto` |
| Deployment target | 27.0 across all platforms |
| Swift language mode | 5.0 |

`SDKROOT = auto` means the SDK follows the destination, so a single scheme
covers every platform. Keep it that way rather than adding per-platform
targets.

## Conventions

- SwiftUI only. No UIKit or AppKit unless a specific API forces it.
- `ContentView.swift` carries a `#Preview` and a `#Playground` block. Keep
  previews working; they are the fastest feedback loop in this project.
- The deployment target is deliberately current, so newer platform APIs may
  be used without availability guards.

## Repository notes

- The remote `origin` is **public**: `github.com/SuperOok/Harmony`. Never
  commit API keys, provisioning profiles, or signing certificates.
- `xcuserdata/` is gitignored. Xcode regenerates the scheme automatically on
  first open, so a fresh clone needs no extra setup.
- The working copy lives in iCloud Drive. If git behaves strangely — missing
  objects, conflicted copies inside `.git/` — suspect iCloud sync before
  suspecting git.
