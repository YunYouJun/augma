import AppKit
import QuartzCore

/// App-lifetime entrance state and interruptible fades for the immersive window group.
@MainActor
final class ImmersivePresentation {
  typealias Animation = @MainActor ([NSWindow], CGFloat, TimeInterval, @escaping @MainActor () -> Void) -> Void

  private var hasPresented = false
  private var revision = 0
  private let animate: Animation

  init(animate: Animation? = nil) {
    self.animate = animate ?? Self.animateWindows
  }

  func show(windows: [NSWindow], reduceMotion: Bool, prepare: (Bool) -> Void) {
    cancel()
    let firstPresentation = !hasPresented
    hasPresented = true
    let duration = firstPresentation || reduceMotion ? 0 : 0.14
    for window in windows {
      if duration == 0 { window.alphaValue = 1 }
      else if !window.isVisible { window.alphaValue = 0 }
    }
    prepare(firstPresentation && !reduceMotion)
    transition(windows: windows, opacity: 1, duration: duration) {}
  }

  func hide(windows: [NSWindow], reduceMotion: Bool, completion: @escaping @MainActor () -> Void) {
    cancel()
    let revision = revision
    transition(windows: windows, opacity: 0, duration: reduceMotion ? 0 : 0.1) { [weak self] in
      // An earlier fade must never unmount a newly revealed scene or restore its old focus.
      guard let self, self.revision == revision else { return }
      completion()
    }
  }

  /// Leaving immersive mode invalidates pending cleanup without replaying Link Start on reentry.
  func cancel() { revision += 1 }

  private func transition(windows: [NSWindow], opacity: CGFloat, duration: TimeInterval,
                          completion: @escaping @MainActor () -> Void) {
    guard duration > 0 else {
      // A zero-duration animator also replaces an in-flight fade when Reduce Motion changes.
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0
        windows.forEach { $0.animator().alphaValue = opacity }
      }
      completion()
      return
    }
    animate(windows, opacity, duration, completion)
  }

  private static func animateWindows(_ windows: [NSWindow], opacity: CGFloat, duration: TimeInterval,
                                     completion: @escaping @MainActor () -> Void) {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = duration
      context.timingFunction = CAMediaTimingFunction(name: opacity == 0 ? .easeIn : .easeOut)
      windows.forEach { $0.animator().alphaValue = opacity }
    } completionHandler: {
      Task { @MainActor in completion() }
    }
  }
}
