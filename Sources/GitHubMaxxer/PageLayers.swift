import CoreGraphics
import Foundation

struct PageLayers {
  let content: CGImage
  let backdrop: CGImage

  init?(_ page: CGImage) {
    let width = page.width
    let height = page.height
    var pixels = [UInt32](repeating: 0, count: width * height)
    let drawn = pixels.withUnsafeMutableBytes { buffer in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(page, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else { return nil }

    var counts = [Int](repeating: 0, count: 4096)
    for pixel in pixels { counts[Self.bin(pixel)] += 1 }
    let isBackground = counts.map { $0 * 10 > pixels.count }

    var content = pixels
    var backdrop = pixels
    for row in 0..<height {
      let span = row * width..<(row + 1) * width
      var surfaces: [Range<Int>] = []
      var run = span.lowerBound
      for index in span.lowerBound...span.upperBound {
        if index < span.upperBound, isBackground[Self.bin(pixels[index])] { continue }
        if index - run >= Self.minimumRun { surfaces.append(run..<index) }
        run = index + 1
      }
      let fills = surfaces.map { pixels[($0.lowerBound + $0.upperBound) / 2] }
      var gap = span.lowerBound
      for (surface, fill) in zip(surfaces, fills) {
        backdrop.replaceSubrange(
          gap..<surface.upperBound, with: repeatElement(fill, count: surface.upperBound - gap))
        content.replaceSubrange(surface, with: repeatElement(0, count: surface.count))
        gap = surface.upperBound
      }
      let tail = fills.last ?? 0
      backdrop.replaceSubrange(
        gap..<span.upperBound, with: repeatElement(tail, count: span.upperBound - gap))
    }
    guard
      let content = Self.image(content, width: width, height: height),
      let backdrop = Self.image(backdrop, width: width, height: height)
    else { return nil }
    self.content = content
    self.backdrop = backdrop
  }

  private static let minimumRun = 12

  private static func bin(_ pixel: UInt32) -> Int {
    Int(pixel >> 4 & 0xF | pixel >> 8 & 0xF0 | pixel >> 12 & 0xF00)
  }

  private static func image(_ pixels: [UInt32], width: Int, height: Int) -> CGImage? {
    guard let provider = CGDataProvider(data: pixels.withUnsafeBytes { Data($0) } as CFData)
    else { return nil }
    return CGImage(
      width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
  }
}
