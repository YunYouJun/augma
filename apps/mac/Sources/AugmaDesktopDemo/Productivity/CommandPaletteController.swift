import AppKit
import SwiftUI

private final class CommandPalettePanel: NSPanel {
  var onDismiss: (() -> Void)?
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func performClose(_ sender: Any?) { onDismiss?() }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown, event.keyCode == 53,
       event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty,
       (firstResponder as? NSTextView)?.hasMarkedText() != true {
      onDismiss?()
      return
    }
    super.sendEvent(event)
  }
}

/// AppKit owns the transient window and focus; SwiftUI owns the glass and command UI.
@MainActor
final class CommandPaletteController: NSObject, NSWindowDelegate {
  private let commands: WorkspaceCommands
  private let store: WorkspaceStore
  private lazy var presentation = CommandPalettePresentation(
    prepareExpansion: { [weak self] in self?.resize(expanded: true) },
    finishCollapse: { [weak self] in self?.resize(expanded: false) }
  )
  private var panel: CommandPalettePanel?
  private var expandedHeight: CGFloat = 580
  private weak var previousWindow: NSWindow?
  private var previousApplication: NSRunningApplication?
  private var revision = 0

  init(commands: WorkspaceCommands, store: WorkspaceStore) {
    self.commands = commands
    self.store = store
  }

  func show(voice: Bool = false, speechMode: WorkspaceCommands.SpeechMode = .command,
            windowLevel: NSWindow.Level = .floating) {
    revision += 1
    let revision = revision
    if voice { commands.preparePendingVoice(mode: speechMode) }
    else { commands.pendingVoice = false }
    if let panel, panel.isVisible {
      panel.level = windowLevel
      NSApp.activate(ignoringOtherApps: true)
      panel.makeKeyAndOrderFront(nil)
      presentation.show(reduceMotion: reduceMotion)
      if voice { commands.startPendingVoice() }
      return
    }
    previousWindow = NSApp.keyWindow
    let frontmost = NSWorkspace.shared.frontmostApplication
    previousApplication = frontmost?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : frontmost
    let screen = previousWindow?.screen
      ?? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    guard let screen else { return }
    let available = screen.visibleFrame.insetBy(dx: 20, dy: 20)
    let size = NSSize(width: min(660, available.width), height: min(580, available.height))
    expandedHeight = size.height
    let panel = self.panel ?? makePanel()
    panel.level = windowLevel
    let origin = NSPoint(x: available.midX - size.width / 2,
                         y: available.maxY - size.height - min(100, max(0, available.height - size.height) / 3))
    panel.setFrame(NSRect(x: origin.x, y: origin.y + size.height - 120, width: size.width, height: 120), display: false)
    let hosting = NSHostingView(rootView: CommandPaletteRoot(
      commands: commands, store: store, presentation: presentation, size: size,
      dismiss: { [weak self] in self?.dismiss() }
    ).appLocalized(windowTitle: "快捷指令"))
    hosting.sizingOptions = []
    // A hosting view installed directly as a window's content view also animates
    // that window's size. Keep the panel's sizing under AppKit ownership.
    let container = NSView(frame: NSRect(origin: .zero, size: panel.frame.size))
    hosting.frame = container.bounds
    hosting.autoresizingMask = [.width, .height]
    container.addSubview(hosting)
    panel.contentView = container
    self.panel = panel
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
    // Mount the empty container before inserting the materializing glass surface.
    Task { @MainActor [weak self] in
      await Task.yield()
      guard let self, self.revision == revision, panel.isVisible else { return }
      self.presentation.show(reduceMotion: self.reduceMotion)
    }
  }

  func dismiss(restoreFocus: Bool = true) {
    guard panel?.isVisible == true, !presentation.isDismissing else { return }
    revision += 1
    commands.cancelVoice()
    guard presentation.visible else {
      closePanel(restoreFocus: restoreFocus)
      return
    }
    presentation.hide(reduceMotion: reduceMotion) { [weak self] in
      self?.closePanel(restoreFocus: restoreFocus)
    }
  }

  private func closePanel(restoreFocus: Bool) {
    panel?.orderOut(nil)
    panel?.contentView = nil
    if restoreFocus, NSApp.isActive {
      if let previousApplication { previousApplication.activate() }
      else if let previousWindow, previousWindow.isVisible { previousWindow.makeKeyAndOrderFront(nil) }
    }
    previousApplication = nil
    previousWindow = nil
  }

  private func resize(expanded: Bool) {
    guard let panel else { return }
    var frame = panel.frame
    let height = expanded ? expandedHeight : 120
    // Reserve space before growing the glass; release it only after the glass has collapsed.
    frame.origin.y += frame.height - height
    frame.size.height = height
    // Never force a display pass from a SwiftUI update. Growing the window inside
    // layout can re-enter AppKit's constraint update pass on macOS 26.
    panel.setFrame(frame, display: false)
  }

  func windowDidResignKey(_ notification: Notification) {
    // A system speech permission dialog must be allowed to complete.
    if commands.speechPhase != "requesting" { dismiss(restoreFocus: false) }
  }

  private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

  private func makePanel() -> CommandPalettePanel {
    let panel = CommandPalettePanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
    panel.title = String(appLocalized: "快捷指令")
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false // Liquid Glass supplies its own shape-aware shadow.
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.hidesOnDeactivate = false
    panel.isMovableByWindowBackground = true
    panel.isReleasedWhenClosed = false
    panel.animationBehavior = .none
    panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    panel.onDismiss = { [weak self] in self?.dismiss() }
    panel.delegate = self
    return panel
  }
}

private struct CommandPaletteRoot: View {
  let commands: WorkspaceCommands
  let store: WorkspaceStore
  @ObservedObject var presentation: CommandPalettePresentation
  let size: NSSize
  let dismiss: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var glass

  var body: some View {
    GlassEffectContainer(spacing: 24) {
      if presentation.visible {
        WorkspaceCommandView(commands: commands, store: store, compact: true,
                             floating: true, expanded: presentation.expanded, onClose: dismiss,
                             onToggleResults: { presentation.setExpanded(!presentation.expanded, reduceMotion: reduceMotion) },
                             onRevealResults: { presentation.setExpanded(true, reduceMotion: reduceMotion) })
          .frame(width: size.width - 40, height: presentation.expanded ? size.height - 40 : 80)
          .glassEffect(.regular, in: .rect(cornerRadius: presentation.expanded ? 28 : 40))
          .glassEffectID("command-palette", in: glass)
          .glassEffectTransition(.materialize)
          .transition(.opacity)
      }
    }
    // Keep padding inside the flexible frame. With it outside, the hosting view's
    // fitting height is the panel height plus 40pt on every layout pass, so
    // NSHostingView keeps growing the window until AppKit aborts the process.
    .padding(20)
    .frame(width: size.width)
    .frame(maxHeight: .infinity, alignment: .top)
    .tint(.augmaCyan)
  }
}
