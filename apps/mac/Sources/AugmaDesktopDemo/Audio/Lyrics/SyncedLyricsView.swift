import SwiftUI

struct SyncedLyricsView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var following = true
  @State private var scrollPhase = ScrollPhase.idle
  let document: LyricsDocument
  let track: NativeNowPlayingTrack

  var body: some View {
    GeometryReader { geometry in
      TimelineView(.animation(minimumInterval: 0.1, paused: !track.playing)) { context in
        let active = track.elapsed(at: context.date).flatMap { document.activeLine(at: $0) }
        ScrollViewReader { proxy in
          ScrollView {
            // Eager measurement keeps scroll targets stable with wrapped translations.
            VStack(alignment: .leading, spacing: 22) {
              ForEach(Array(document.lines.enumerated()), id: \.offset) { index, line in
                lyric(line, active: active == index, hasActiveLine: active != nil)
                  .id(index)
              }
            }
            // The first and last lines can reach the same central reading position.
            .padding(.vertical, max(24, (geometry.size.height - 56) / 2))
            .padding(.horizontal, 2)
          }
          .modifier(LyricsScrollStyle())
          .accessibilityLabel("同步歌词")
          .onScrollPhaseChange { _, phase in
            scrollPhase = phase
            if phase == .tracking || phase == .interacting { following = false }
          }
          .task(id: scrollPhase) {
            guard scrollPhase == .idle, !following else { return }
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            following = true
          }
          .onAppear { scroll(proxy, to: active, animated: false) }
          .onChange(of: active) { _, index in
            if following { scroll(proxy, to: index) }
          }
          .onChange(of: following) { _, enabled in
            if enabled { scroll(proxy, to: active) }
          }
          .onChange(of: geometry.size) { _, _ in
            if following { scroll(proxy, to: active, animated: false) }
          }
          .overlay(alignment: .bottomTrailing) {
            if !following {
              Button("回到当前歌词", systemImage: "arrow.uturn.backward") { following = true }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(8)
            }
          }
        }
      }
    }
    .frame(minHeight: 160, maxHeight: .infinity)
  }

  private func lyric(_ line: LyricsLine, active: Bool, hasActiveLine: Bool) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(line.text.isEmpty ? " " : line.text)
        // A constant size and weight avoid reflow when the current line changes.
        .font(.system(size: 18, weight: .semibold))
      if let translation = line.translation {
        Text(translation).font(.callout)
          .foregroundStyle(active ? Color.primary.opacity(0.8) : Color.secondary)
      }
    }
    .foregroundStyle(active ? Color.primary : Color.secondary)
    .opacity(!hasActiveLine || active ? 1 : 0.6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 6)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: active)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(active ? .isSelected : [])
  }

  private func scroll(_ proxy: ScrollViewProxy, to index: Int?, animated: Bool = true) {
    withAnimation(animated && !reduceMotion ? .smooth(duration: 0.6, extraBounce: 0) : nil) {
      proxy.scrollTo(index ?? 0, anchor: .center)
    }
  }
}
