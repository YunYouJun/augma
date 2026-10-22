import AppKit

// usage: swift create_app_icon.swift <augma-app-icon.svg> <AppIcon.iconset>
// The SVG is the full-bleed square artwork shared with YunLeFun/icons; macOS
// icns files are not masked by the system, so the squircle and shadow follow
// Apple's 1024 px macOS template (824 px body, 100 px margin) here.
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let directory = URL(fileURLWithPath: CommandLine.arguments[2])
guard let artwork = NSImage(contentsOf: source) else {
  FileHandle.standardError.write("Cannot read \(source.path)\n".data(using: .utf8)!)
  exit(1)
}
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

// Draw each size straight into an sRGB bitmap: an intermediate lockFocus image
// is cached in the display colour space and shifts the brand navy.
func drawIcon(pixels: Int) -> NSBitmapImageRep {
  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!.retagging(with: .sRGB)!
  let unit = CGFloat(pixels) / 1024
  let body = NSRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
  let shape = NSBezierPath(roundedRect: body, xRadius: 185 * unit, yRadius: 185 * unit)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
  shadow.shadowOffset = NSSize(width: 0, height: -10 * unit)
  shadow.shadowBlurRadius = 20 * unit
  shadow.set()
  NSColor.black.setFill()
  shape.fill()
  NSGraphicsContext.restoreGraphicsState()
  shape.addClip()
  artwork.draw(in: body)
  NSGraphicsContext.restoreGraphicsState()
  return bitmap
}

for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let suffix = scale == 2 ? "@2x" : ""
    try drawIcon(pixels: size * scale).representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
  }
}
