import SwiftUI

@MainActor
final class VoiceActivityModel: ObservableObject {
  @Published private(set) var phase = "idle"
  @Published private(set) var level: Double = 0

  func setPhase(_ value: String) {
    if phase != value { phase = value }
    if value != "listening", level != 0 { level = 0 }
  }

  func receive(level value: Double) {
    guard phase == "listening", value.isFinite else { return }
    let next = min(1, max(0, value))
    let smoothed = level + (next - level) * (next > level ? 0.65 : 0.3)
    if abs(smoothed - level) > 0.005 { level = smoothed }
  }
}

/// Observes only the meter; the main window does not redraw at microphone frequency.
struct VoiceActivityView: View {
  @ObservedObject var activity: VoiceActivityModel

  var body: some View {
    VoiceActivityGlyph(phase: activity.phase, level: activity.level)
  }
}

struct VoiceActivityGlyph: View {
  let phase: String
  let level: Double
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  private var working: Bool { ["requesting", "processing", "interpreting"].contains(phase) }

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 24, paused: !working || reduceMotion || scenePhase != .active)) { context in
      let time = working && !reduceMotion ? context.date.timeIntervalSinceReferenceDate : 0
      VStack(spacing: 16) {
        ZStack {
          Circle()
            .fill(Color.augmaCyan.opacity(phase == "listening" ? 0.10 + level * 0.14 : 0.08))
          Circle()
            .stroke(.quaternary, lineWidth: 1)
          Circle()
            .trim(from: 0.08, to: working ? 0.72 : 0.92)
            .stroke(AngularGradient(colors: [.augmaCyan, .augmaHighlight, .augmaCyan], center: .center), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .rotationEffect(.degrees(working ? time.truncatingRemainder(dividingBy: 3) / 3 * 360 : -90))
            .padding(4)
          Image(systemName: phase == "error" ? "exclamationmark" : working ? "sparkles" : "mic.fill")
            .font(.system(size: 27, weight: .medium))
            .foregroundStyle(phase == "error" ? Color.red : .primary)
        }
        .frame(width: 88, height: 88)
        .scaleEffect(reduceMotion || phase != "listening" ? 1 : 1 + level * 0.05)

        HStack(alignment: .center, spacing: 4) {
          ForEach(0..<19) { index in
            let envelope = 0.25 + 0.75 * sin(Double(index + 1) / 20 * .pi)
            let amplitude = phase == "listening" ? level : working ? 0.2 + 0.12 * sin(time * 4 + Double(index) * 0.6) : 0
            Capsule()
              .fill(index < 10 ? Color.augmaCyan : .augmaAccent)
              .frame(width: 4, height: reduceMotion ? 5 : 4 + 26 * max(0, amplitude) * envelope)
          }
        }
        .frame(height: 32)
        if reduceMotion && phase == "listening" {
          // Keep a steady, meaningful level indicator when decorative motion is disabled.
          ProgressView(value: level).frame(width: 148)
        }
      }
      .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: level)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
    }
    .accessibilityHidden(true)
  }
}

struct VoiceEffectPreview: View {
  @Environment(\.dismiss) private var dismiss
  @State private var phase = "listening"
  @State private var level = 0.6

  var body: some View {
    VStack(spacing: 16) {
      Text("语音动效预览").font(.headline)
      Picker("语音状态", selection: $phase) {
        Text("待命").tag("idle")
        Text("聆听").tag("listening")
        Text("处理中").tag("processing")
      }
      .pickerStyle(.segmented)
      VoiceActivityGlyph(phase: phase, level: phase == "listening" ? level : 0)
      Slider(value: $level) { Text("示例音量") }.disabled(phase != "listening")
      Text("仅预览动画，不使用麦克风。").font(.caption).foregroundStyle(.secondary)
      Button("完成") { dismiss() }.keyboardShortcut(.defaultAction)
    }
    .padding(24)
    .frame(width: 360)
  }
}
