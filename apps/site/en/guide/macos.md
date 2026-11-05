# macOS app

The macOS app puts the [AR demo](/en/guide/ar) in a native window: switch apps from the sidebar, and the interface works offline. Immersive mode lays a transparent overlay over your desktop, and you can also drive the demo with voice commands.

<div class="macos-downloads">
  <a class="agm-button agm-button--primary macos-download" href="https://github.com/YunYouJun/augma/releases/latest/download/Augma-macOS-arm64.zip">Download for Apple silicon</a>
  <a class="agm-button agm-button--outline macos-download" href="https://github.com/YunYouJun/augma/releases/latest/download/Augma-macOS-x86_64.zip">Download for Intel</a>
</div>

Requires macOS 26 or later. Check Apple menu → About This Mac: choose arm64 for Apple silicon or x86_64 for an Intel processor. Earlier versions and per-architecture SHA-256 checksums are on [GitHub Releases](https://github.com/YunYouJun/augma/releases).

## Install and first launch

1. Unzip the matching `Augma-macOS-arm64.zip` or `Augma-macOS-x86_64.zip` and drag `Augma.app` into the Applications folder.
2. Double-click to open it. The app is not yet signed with an Apple Developer certificate or notarized, so macOS says it cannot be verified; click Done.
3. Open System Settings → Privacy & Security, click Open Anyway under Security and confirm. From then on it opens without the warning.

## What you can do

- **Demo window**: open weather, sound, space, camera, navigation and the other apps from the sidebar, just like the web AR demo; turn on Always on Top from the toolbar.
- **Immersive mode**: the interface floats over the current display as a transparent overlay, and clicks on empty areas pass through; the control bar at the top right switches apps, hands control back to the desktop or exits.
- **Voice commands**: click the microphone at the top left or press `⌥⌘V`, then say a command such as "open the map" or "start navigation", in English, Chinese or Japanese. The first time, macOS asks for microphone and speech recognition permission. To use another key, add the menu title "Start or Finish Voice Command" for Augma in System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts.
- **Languages**: menus and settings follow the macOS language (简体中文, English, 日本語); you can pick a language for Augma alone in System Settings → General → Language & Region → Applications. The demo interface's language can also be switched in its Settings panel.

The camera and WebXR depend on WebKit's support for local pages; the simulated interface does not need those permissions. The optional DeepSeek assistant, which answers questions or runs demo actions, needs your own API key; see the [app README](https://github.com/YunYouJun/augma/tree/main/apps/mac).

## Build from source

You need Node.js 24, pnpm and Xcode 26 or later. From the repository root, `pnpm mac:run` builds and launches arm64 by default; Intel Mac developers can use `AUGMA_BUILD_ARCH=x86_64 pnpm mac:run`. `pnpm mac:package` produces both Release packages, `apps/mac/dist/Augma-macOS-arm64.zip` and `Augma-macOS-x86_64.zip`, each with a `.sha256` file. Run `pnpm mac:package arm64` or `pnpm mac:package x86_64` to package just one architecture.
