import AppKit
import SwiftUI

struct NativePlayerSourceLabel: View {
  private static let icon: NSImage? = NSWorkspace.shared
    .urlForApplication(withBundleIdentifier: NativeNowPlayingTrack.neteaseBundleIdentifier)
    .map { NSWorkspace.shared.icon(forFile: $0.path) }

  var body: some View {
    Label {
      Text("网易云音乐")
    } icon: {
      if let icon = Self.icon {
        Image(nsImage: icon).resizable().scaledToFit().frame(width: 16, height: 16)
      } else {
        Image(systemName: "music.note")
      }
    }
    .font(.caption).foregroundStyle(.secondary)
  }
}
