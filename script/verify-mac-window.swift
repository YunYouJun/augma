import CoreGraphics
import Foundation

let deadline = Date().addingTimeInterval(8)

while Date() < deadline {
  let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
  if windows.contains(where: {
    ($0[kCGWindowOwnerName as String] as? String) == "Augma"
      && ($0[kCGWindowName as String] as? String) == "Augma"
  }) {
    print("Augma main window is visible on the current desktop")
    exit(EXIT_SUCCESS)
  }
  Thread.sleep(forTimeInterval: 0.2)
}

fputs("Augma main window did not appear on the current desktop\n", stderr)
exit(EXIT_FAILURE)
