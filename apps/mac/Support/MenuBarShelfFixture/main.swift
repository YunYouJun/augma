import AppKit

final class ShelfFixtureDelegate: NSObject, NSApplicationDelegate {
  private var items: [NSStatusItem] = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    for index in 1...4 {
      let item = NSStatusBar.system.statusItem(withLength: 42)
      item.button?.title = "AG\(index)"
      item.button?.toolTip = "Augma Shelf Fixture \(index)"
      let menu = NSMenu(title: "Augma Shelf Fixture \(index)")
      let action = NSMenuItem(title: "Test menu action \(index)", action: #selector(testAction), keyEquivalent: "")
      action.target = self
      menu.addItem(action)
      let submenu = NSMenuItem(title: "Submenu", action: nil, keyEquivalent: "")
      let children = NSMenu(title: "Submenu")
      let nested = NSMenuItem(title: "Test menu action nested", action: #selector(testAction), keyEquivalent: "")
      nested.target = self
      children.addItem(nested)
      submenu.submenu = children
      menu.addItem(submenu)
      item.menu = menu
      items.append(item)
    }
  }

  @objc private func testAction() { }
}

let app = NSApplication.shared
let delegate = ShelfFixtureDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
