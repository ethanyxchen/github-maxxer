import AppKit

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let surface = NSBezierPath(
  roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 216, yRadius: 216)
NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.13, alpha: 1).setFill()
surface.fill()
let levels = [
  [0, 0, 1, 0, 2, 0, 0],
  [1, 2, 2, 1, 3, 2, 1],
  [2, 3, 4, 3, 4, 3, 2],
  [1, 3, 4, 4, 4, 3, 1],
  [0, 2, 3, 4, 3, 2, 0],
  [0, 1, 2, 3, 2, 1, 0],
  [0, 0, 1, 2, 1, 0, 0],
]
let colors = [
  NSColor(calibratedRed: 0.21, green: 0.24, blue: 0.22, alpha: 1),
  NSColor(calibratedRed: 0.15, green: 0.37, blue: 0.23, alpha: 1),
  NSColor(calibratedRed: 0.19, green: 0.53, blue: 0.30, alpha: 1),
  NSColor(calibratedRed: 0.28, green: 0.72, blue: 0.40, alpha: 1),
  NSColor(calibratedRed: 0.49, green: 0.88, blue: 0.54, alpha: 1),
]
for row in 0..<7 {
  for column in 0..<7 {
    let rect = NSRect(x: 204 + column * 90, y: 744 - row * 90, width: 76, height: 76)
    colors[levels[row][column]].setFill()
    NSBezierPath(roundedRect: rect, xRadius: 13, yRadius: 13).fill()
  }
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let data = bitmap.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
