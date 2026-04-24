# CyberBrowser - iOS Browser with Real Chromium Blink Engine

A real iOS browser built on the **Chromium ios_web** engine (content_shell), featuring a custom tabbed browser UI with address bar, navigation, history, and Google search integration.

## Architecture

```
CyberBrowser/
├── .github/workflows/build-blink.yml  # CI/CD: Builds real Chromium on macOS
├── patches/
│   └── CyberBrowserViewController.mm.patch  # Patches Chromium's view_controller.mm
│   └── view_controller_tabbed.patch     # Diff patch (alternative)
├── scripts/
│   ├── fetch-chromium.sh              # Fetches Chromium iOS source
│   ├── apply-patches.sh               # Applies CyberBrowser patches
│   └── build.sh                       # Builds ios_web_shell target
├── src/                               # Standalone Swift/UIKit fallback
│   ├── ChromiumInit.h/mm              # Objective-C++ Chromium WebMain init
│   ├── BrowserViewController.h/mm     # Standalone browser UI (fallback)
│   ├── AppDelegate.h/mm               # App lifecycle
│   └── SceneDelegate.h/mm             # iOS 13+ multi-window
└── CyberBrowser/
    └── Info.plist                     # App bundle config
```

## How It Works

### The Real Build (GitHub Actions CI)

1. **Fetch Chromium iOS Source** (~30GB, cached between builds)
2. **Apply Patches** - Replaces `ios/web/shell/view_controller.mm` with CyberBrowser UI
3. **Build** `ios_web_shell` target using `autoninja` (2-6 hours)
4. **Package** as `CyberBrowser.app` + `.tipa` for TrollStore

### Chromium API Used (Verified from Source)

- `web::WebState` - Core web engine interface
  - `GetView()` - Returns `UIView*` containing the web content
  - `GetNavigationManager()` - Navigation control
  - `GetVisibleURL()` / `GetTitle()` / `IsLoading()` / `GetLoadingProgress()`
  - `OpenURL()` / `Stop()` / `SetWebUsageEnabled()`
- `web::NavigationManager` - Back/forward navigation
  - `CanGoBack()` / `CanGoForward()` / `GoBack()` / `GoForward()`
  - `LoadURLWithParams()` / `Reload()`
- `web::WebMain` - Engine initialization (must call `Startup()` before any web ops)
- `web::ShellMainDelegate` / `web::ShellWebClient` - Required delegates

### Patches Applied

The `patches/CyberBrowserViewController.mm.patch` replaces Chromium's simple shell UI with:

- **Progress bar** - Shows loading progress via `WebState::GetLoadingProgress()`
- **Address bar** - URL entry with Google search fallback
- **Back/Forward/Reload** - Real navigation via `NavigationManager`
- **History** - Stores visited URLs in `NSUserDefaults` with 500-item cap
- **Tab management** - UIAlertController-based tab picker
- **Context menus** - Link copy/paste support

## Building Locally

```bash
# 1. Fetch Chromium source (one-time, ~30GB)
./scripts/fetch-chromium.sh

# 2. Apply patches
./scripts/apply-patches.sh

# 3. Build (takes 2-6 hours on first run)
./scripts/build.sh

# Output: build-output/CyberBrowser.app
```

## CI/CD (GitHub Actions)

The `.github/workflows/build-blink.yml` runs on `macos-15` with Xcode 16.1:

1. Caches `depot_tools` and Chromium source (30GB+)
2. Syncs latest source via `gclient sync`
3. Applies CyberBrowser patches
4. Builds `ios_web_shell` with `autoninja`
5. Packages as `.app`, `.ipa`, and `.tipa`
6. Uploads artifacts + creates GitHub Release

## Installation

### TrollStore (iOS 15+, recommended)
1. Install TrollStore on your device
2. Transfer `CyberBrowser.tipa` to device
3. Open TrollStore → tap `+` → select `.tipa`

### AltStore / SideStore
1. Use `CyberBrowser.ipa`
2. Sideload with your preferred tool

## Development

### Standalone Mode (No Chromium)

The `src/` directory contains a standalone Swift/Objective-C++ browser that can be built independently. It attempts to initialize Chromium but shows an error if the engine is not available.

```bash
# Build standalone (requires Xcode)
xcodebuild -project CyberBrowser.xcodeproj -scheme CyberBrowser -destination 'generic/platform=iOS'
```

## License

BSD-3-Clause (Chromium components remain under their respective licenses)
