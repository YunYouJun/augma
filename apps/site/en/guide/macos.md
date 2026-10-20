# macOS app

The macOS app puts the [AR demo](/en/guide/ar) in a native window: switch apps from the sidebar, and the interface works offline. Immersive mode lays a transparent overlay over your desktop, and you can also drive the demo with voice commands.

<a class="agm-button agm-button--primary macos-download" href="https://github.com/YunYouJun/augma/releases/latest/download/Augma-macOS.zip">Download Augma for macOS</a>

Requires macOS 15 or later, on Macs with Apple silicon or Intel processors. Earlier versions and SHA-256 checksums are on [GitHub Releases](https://github.com/YunYouJun/augma/releases).

## Install and first launch

1. Unzip `Augma-macOS.zip` and drag `Augma.app` into the Applications folder.
2. Double-click to open it. The app is not yet signed with an Apple Developer certificate or notarized, so macOS says it cannot be verified; click Done.
3. Open System Settings → Privacy & Security, click Open Anyway under Security and confirm. From then on it opens without the warning.

## What you can do

- **Demo window**: open weather, sound, space, camera, navigation and the other apps from the sidebar, just like the web AR demo; turn on Always on Top from the toolbar.
- **Immersive mode**: the interface floats over the current display as a transparent overlay, and clicks on empty areas pass through; the control bar at the top right switches apps, hands control back to the desktop or exits.
- **Voice commands**: click the microphone at the top left or press `⌘⇧V`, then say a command such as "open the map" or "start navigation", in English, Chinese or Japanese. The first time, macOS asks for microphone and speech recognition permission.
- **Languages**: menus and settings follow the macOS language (简体中文, English, 日本語); you can pick a language for Augma alone in System Settings → General → Language & Region → Applications. The demo interface's language can also be switched in its Settings panel.

The camera and WebXR depend on WebKit's support for local pages; the simulated interface does not need those permissions. The optional DeepSeek assistant, which answers questions or runs demo actions, needs your own API key; see the [app README](https://github.com/YunYouJun/augma/tree/main/apps/mac).

## Build from source

You need Node.js 24, pnpm and Xcode. From the repository root, run `pnpm mac:run` to build and launch; `pnpm mac:package` produces the same universal package as the release, `apps/mac/dist/Augma-macOS.zip`.
