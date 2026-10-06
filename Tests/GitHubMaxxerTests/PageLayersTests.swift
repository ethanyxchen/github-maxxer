import CoreGraphics
import Foundation
import Testing

@testable import GitHubMaxxer

struct PageLayersTests {
  @Test func separatesContentFromBackgroundIncludingBackgroundColoredText() throws {
    let background: UInt32 = 0xFFEF_F2F1
    let ink: UInt32 = 0xFF14_1714
    var pixels = [UInt32](repeating: background, count: 200 * 4)
    for row in 0..<4 {
      for column in 40..<56 { pixels[row * 200 + column] = ink }
      for column in 47..<50 { pixels[row * 200 + column] = background }
    }

    let layers = try #require(PageLayers(image(pixels, width: 200, height: 4)))
    let content = try bytes(layers.content)
    let backdrop = try bytes(layers.backdrop)

    #expect(content[10] == 0)
    #expect(content[45] == ink)
    #expect(content[48] == background)
    #expect(backdrop[45] == background)
    #expect(backdrop[48] == background)
  }
}

private func image(_ pixels: [UInt32], width: Int, height: Int) -> CGImage {
  CGImage(
    width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
    provider: CGDataProvider(data: pixels.withUnsafeBytes { Data($0) } as CFData)!, decode: nil,
    shouldInterpolate: false, intent: .defaultIntent)!
}

private func bytes(_ image: CGImage) throws -> [UInt32] {
  let data = try #require(image.dataProvider?.data as Data?)
  return data.withUnsafeBytes { Array($0.bindMemory(to: UInt32.self)) }
}
