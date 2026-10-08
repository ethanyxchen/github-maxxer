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
    var tallies = [UInt32: Int]()
    for pixel in pixels where isBackground[Self.bin(pixel)] { tallies[pixel, default: 0] += 1 }
    var tones = [(pixel: UInt32, count: Int)](repeating: (0, 0), count: 4096)
    for (pixel, count) in tallies where count > tones[Self.bin(pixel)].count {
      tones[Self.bin(pixel)] = (pixel, count)
    }

    var isTall = [Bool](repeating: false, count: pixels.count)
    for column in 0..<width {
      let runs = Self.runs(count: height) { isBackground[Self.bin(pixels[$0 * width + column])] }
      for row in runs.joined() { isTall[row * width + column] = true }
    }

    var content = pixels
    var backdrop = pixels
    for row in 0..<height {
      let span = row * width..<(row + 1) * width
      let surfaces = Self.runs(count: width) { isTall[span.lowerBound + $0] }.map {
        $0.lowerBound + span.lowerBound..<$0.upperBound + span.lowerBound
      }
      let fills = surfaces.map {
        tones[Self.bin(pixels[($0.lowerBound + $0.upperBound) / 2])].pixel
      }
      var gap = span.lowerBound
      for (surface, fill) in zip(surfaces, fills) {
        backdrop.replaceSubrange(
          gap..<surface.upperBound, with: repeatElement(fill, count: surface.upperBound - gap))
        for index in surface where pixels[index] == fill { content[index] = 0 }
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

  private static func runs(count: Int, where isFlat: (Int) -> Bool) -> [Range<Int>] {
    var runs: [Range<Int>] = []
    var start = 0
    for position in 0...count {
      if position < count, isFlat(position) { continue }
      if position - start >= minimumRun { runs.append(start..<position) }
      start = position + 1
    }
    return runs
  }

  private static func bin(_ pixel: UInt32) -> Int {
    let low: UInt32 = pixel >> 4 & 0xF
    let middle: UInt32 = pixel >> 8 & 0xF0
    let high: UInt32 = pixel >> 12 & 0xF00
    return Int(low | middle | high)
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
