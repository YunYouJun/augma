import AppKit
import ApplicationServices
import Combine
import OSLog

@MainActor
final class MenuBarShelfStore: ObservableObject {
  static let enabledKey = "augma.menu-bar-shelf.enabled"
  static let originalIconsKey = "augma.menu-bar-shelf.original-icons"
  @Published var enabled: Bool {
    didSet {
      guard enabled != oldValue else { return }
      defaults.set(enabled, forKey: Self.enabledKey)
      if started { enabled ? enable() : disable() }
    }
  }
  @Published var originalIcons: Bool {
    didSet {
      defaults.set(originalIcons, forKey: Self.originalIconsKey)
      if !originalIcons { images = [:] }
      if enabled && isShowing { refresh() }
    }
  }
  @Published private(set) var accessibilityAllowed = false
  @Published private(set) var captureAllowed = false
  @Published private(set) var items: [MenuBarShelfItem] = []
  @Published private(set) var images: [CGWindowID: NSImage] = [:]
  @Published private(set) var isShowing = false
  @Published private(set) var isRefreshing = false
  @Published private(set) var isBusy = false
  @Published private(set) var error: String?
  @Published private(set) var shortcutAvailable = false
  @Published private(set) var hasNotchedDisplay = false
  @Published private(set) var needsIconAccess = false
  var onExitImmersive: (() -> Void)?
  var onNextImmersiveControl: (() -> Void)?
  private let defaults: UserDefaults
  private let client: any MenuBarShelfInteracting
  private let currentDisplay: () -> MenuBarShelfDisplay?
  private let session: MenuBarShelfSession
  private let shortcut = MenuBarShelfShortcut()
  private lazy var panel = MenuBarShelfPanel(store: self)
  private var started = false
  private var refreshTask: Task<Void, Never>?
  private var operationTask: Task<Void, Never>?
  private var pollTask: Task<Void, Never>?
  private var screenObserver: NSObjectProtocol?
  private var immersiveScreen: NSScreen?
  private(set) var immersiveClockVisible = false
  private var revision = 0
  private let logger = Logger(subsystem: "cn.yunyoujun.augma.desktop-demo", category: "menu-bar-shelf")

  init(defaults: UserDefaults = .standard,
       client: any MenuBarShelfInteracting = MenuBarShelfClient(),
       currentDisplay: @escaping () -> MenuBarShelfDisplay? = { MenuBarShelfDisplay.current() }) {
    self.defaults = defaults
    self.client = client
    self.currentDisplay = currentDisplay
    session = MenuBarShelfSession(client: client, defaults: defaults)
    enabled = defaults.bool(forKey: Self.enabledKey)
    originalIcons = defaults.bool(forKey: Self.originalIconsKey)
  }

  func start() {
    guard !started else { return }
    started = true
    if enabled { enable() }
  }

  private func enable() {
    refreshPermissions()
    shortcutAvailable = shortcut.register { [weak self] in self?.toggle() }
    screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
      object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated {
          if self?.isBusy != true { self?.hide() }
          self?.refreshPermissions()
        }
      }
  }

  private func disable() {
    immersiveScreen = nil
    hide()
    refreshTask?.cancel()
    refreshTask = nil
    revision += 1
    isRefreshing = false
    shortcut.unregister()
    shortcutAvailable = false
    if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    screenObserver = nil
    operationTask?.cancel() // The session closes only its own native menu before finishing.
    items = []
    images = [:]
    accessibilityAllowed = false
    captureAllowed = false
    needsIconAccess = false
  }

  func refreshPermissions() {
    guard enabled else { return }
    accessibilityAllowed = AXIsProcessTrusted()
    captureAllowed = CGPreflightScreenCaptureAccess()
    hasNotchedDisplay = currentDisplay() != nil
  }

  func requestAccessibility() {
    guard enabled else { return }
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    openPrivacy("Privacy_Accessibility")
  }

  func requestCapture() {
    guard enabled else { return }
    if !CGPreflightScreenCaptureAccess() { _ = CGRequestScreenCaptureAccess() }
    refreshPermissions()
    if !captureAllowed { openPrivacy("Privacy_ScreenCapture") }
    else if isShowing { refresh() }
  }

  private func openPrivacy(_ pane: String) {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
      NSWorkspace.shared.open(url)
    }
  }

  func toggle() { isShowing ? hide() : show() }

  var isPresentedInImmersive: Bool { immersiveScreen != nil && (isShowing || isBusy) }
  var immersiveWindow: NSPanel? { immersiveScreen != nil && isShowing ? panel.window : nil }

  func showInImmersive(on screen: NSScreen, clockVisible: Bool = false) {
    guard enabled, currentDisplay() != nil else {
      hideFromImmersive()
      if isShowing { hide() }
      return
    }
    let wasInImmersive = immersiveScreen != nil
    immersiveScreen = screen
    immersiveClockVisible = clockVisible
    if isShowing && wasInImmersive {
      panel.updateImmersiveFrame(on: screen, clockVisible: clockVisible)
      return
    }
    show()
  }

  func hideFromImmersive() {
    guard immersiveScreen != nil else { return }
    immersiveScreen = nil
    hide()
  }

  func show() {
    guard enabled, !isBusy, currentDisplay() != nil else { return }
    refreshPermissions()
    panel.show(in: immersiveScreen)
    isShowing = true
    refresh()
    startPolling()
  }

  private func startPolling() {
    pollTask?.cancel()
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(3)) } catch { return }
        guard let self, self.enabled, self.isShowing else { return }
        if self.originalIcons && self.captureAllowed && !self.isBusy && !self.isRefreshing {
          let images = await self.client.images(for: self.items)
          guard !Task.isCancelled, self.enabled, self.isShowing, self.originalIcons else { return }
          self.images = images
        }
      }
    }
  }

  func hide() {
    isShowing = false
    panel.hide()
    pollTask?.cancel()
    pollTask = nil
    refreshTask?.cancel()
    refreshTask = nil
    revision += 1
    isRefreshing = false
  }

  func refresh(clearError: Bool = false) {
    guard enabled, !isBusy, refreshTask == nil else { return }
    if clearError { error = nil }
    refreshPermissions()
    guard accessibilityAllowed, let display = currentDisplay() else { items = []; images = [:]; return }
    revision += 1
    let ticket = revision
    isRefreshing = true
    refreshTask = Task { [weak self] in
      guard let self else { return }
      defer {
        if self.revision == ticket { self.isRefreshing = false; self.refreshTask = nil }
      }
      do {
        let scanned = try await self.client.items(on: display)
        guard !Task.isCancelled, self.enabled, self.revision == ticket else { return }
        self.items = scanned.filter {
          display.isOccluded($0.window) && $0.applicationPID != ProcessInfo.processInfo.processIdentifier
        }
        self.needsIconAccess = !self.captureAllowed && NSScreen.screens.count > 1
          && !self.items.isEmpty && self.items.allSatisfy { !$0.canOpenMenu }
        if self.originalIcons && self.captureAllowed && self.isShowing {
          let images = await self.client.images(for: self.items)
          guard !Task.isCancelled, self.enabled, self.originalIcons, self.isShowing, self.revision == ticket else { return }
          self.images = images
        }
      } catch is CancellationError { }
      catch {
        guard self.enabled, self.revision == ticket else { return }
        self.error = error.localizedDescription
      }
    }
  }

  private func pauseForMenuOperation() {
    pollTask?.cancel()
    refreshTask?.cancel()
    refreshTask = nil
    revision += 1
    isRefreshing = false
    isBusy = true
    error = nil
  }

  func open(_ item: MenuBarShelfItem, rightClick: Bool = false) {
    guard enabled, !isBusy, let display = currentDisplay() else { return }
    let openedInImmersive = immersiveScreen != nil
    pauseForMenuOperation()
    operationTask = Task { [weak self] in
      guard let self else { return }
      do {
        self.hide()
        // Release the shelf before asking the original application to show its own menu.
        try await Task.sleep(for: .milliseconds(80))
        try await self.session.open(item, on: display, rightClick: rightClick)
        self.logger.notice("Direct native menu completed without moving status items")
      } catch is CancellationError { }
      catch {
        self.error = error.localizedDescription
        self.logger.error("Menu bar operation: \(error.localizedDescription, privacy: .public)")
      }
      self.hide()
      self.isBusy = false
      self.operationTask = nil
      if self.enabled && (self.immersiveScreen != nil || (!openedInImmersive && self.error != nil)) { self.show() }
    }
  }

  func shutdown() async {
    let operation = operationTask
    disable()
    await operation?.value
  }
}
