import SwiftUI

/// Keeps the input mounted while the glass expands, and ignores superseded animation completions.
@MainActor
final class CommandPalettePresentation: ObservableObject {
  typealias Animate = @MainActor (Animation, () -> Void, @escaping @MainActor () -> Void) -> Void

  @Published private(set) var visible = false
  @Published private(set) var expanded = false
  private(set) var isDismissing = false
  private var revision = 0
  private let animate: Animate
  private let prepareExpansion: @MainActor () -> Void
  private let finishCollapse: @MainActor () -> Void

  init(animate: Animate? = nil, prepareExpansion: @escaping @MainActor () -> Void = {},
       finishCollapse: @escaping @MainActor () -> Void = {}) {
    self.animate = animate ?? { animation, changes, completion in
      withAnimation(animation, completionCriteria: .removed, changes, completion: completion)
    }
    self.prepareExpansion = prepareExpansion
    self.finishCollapse = finishCollapse
  }

  func show(reduceMotion: Bool) {
    revision += 1
    isDismissing = false
    let revision = revision
    if reduceMotion {
      prepareExpansion()
      visible = true
      expanded = true
    } else if visible {
      setExpanded(true, reduceMotion: false)
    } else {
      animate(.easeOut(duration: 0.12), { self.visible = true }) { [weak self] in
        guard let self, self.revision == revision else { return }
        self.setExpanded(true, reduceMotion: false)
      }
    }
  }

  func setExpanded(_ value: Bool, reduceMotion: Bool) {
    guard !isDismissing else { return }
    revision += 1
    let revision = revision
    guard expanded != value else { return }
    if value { prepareExpansion() }
    if reduceMotion {
      expanded = value
      if !value { finishCollapse() }
    } else {
      animate(.spring(duration: 0.3, bounce: 0.1), { self.expanded = value }) { [weak self] in
        guard let self, self.revision == revision, !self.expanded else { return }
        self.finishCollapse()
      }
    }
  }

  func hide(reduceMotion: Bool, completion: @escaping @MainActor () -> Void) {
    guard visible, !isDismissing else { return }
    revision += 1
    let revision = revision
    isDismissing = true
    if reduceMotion {
      expanded = false
      visible = false
      finishCollapse()
      completion()
      return
    }
    animate(.spring(duration: 0.22, bounce: 0), { self.expanded = false }) { [weak self] in
      guard let self, self.revision == revision else { return }
      self.finishCollapse()
      self.animate(.easeOut(duration: 0.12), { self.visible = false }) { [weak self] in
        guard self?.revision == revision else { return }
        completion()
      }
    }
  }
}
