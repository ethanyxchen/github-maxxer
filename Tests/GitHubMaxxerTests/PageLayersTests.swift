import CoreGraphics
import Foundation
import Testing

@testable import GitHubMaxxer

struct PageLayersTests {
  @Test func separatesContentFromBackgroundIncludingBackgroundColoredText() throws {
    let background: UInt32 = 0xFFEF_F2F1
    let ink: UInt32 = 0xFF14_1714
    var pixels = [UInt32](repeating: background, count: 200 * 16)
    for row in 0..<16 {
      for column in 40..<56 { pixels[row * 200 + column] = ink }
      for column in 47..<50 { pixels[row * 200 + column] = background }
    }

    let layers = try #require(PageLayers(image(pixels, width: 200, height: 16)))
    let content = try bytes(layers.content)
    let backdrop = try bytes(layers.backdrop)

    #expect(content[10] == 0)
    #expect(content[45] == ink)
    #expect(content[48] == background)
    #expect(backdrop[45] == background)
    #expect(backdrop[48] == background)
  }

  @Test func fillsBackdropWithoutSmearingAntialiasedEdges() throws {
    let background: UInt32 = 0xFFEF_F2F1
    let edge: UInt32 = 0xFFE0_F0F0
    let ink: UInt32 = 0xFF14_1714
    var pixels = [UInt32](repeating: background, count: 200 * 16)
    for row in 0..<16 {
      pixels[row * 200 + 39] = edge
      for column in 40..<56 { pixels[row * 200 + column] = ink }
    }

    let layers = try #require(PageLayers(image(pixels, width: 200, height: 16)))
    let backdrop = try bytes(layers.backdrop)

    #expect(backdrop[39] == background)
    #expect(backdrop[45] == background)
    #expect(backdrop[60] == background)
  }

  @Test func ignoresThinBackgroundColoredStrokesInsideContent() throws {
    let sidebar: UInt32 = 0xFFD9_DEDC
    let page: UInt32 = 0xFFEF_F2F1
    let ink: UInt32 = 0xFF14_1714
    var pixels = (0..<200 * 80).map { $0 % 200 < 100 ? sidebar : page }
    for row in 0..<80 { pixels[row * 200 + 100] = ink }
    for row in 10..<30 {
      for column in 20..<60 { pixels[row * 200 + column] = ink }
    }
    for column in 30..<50 { pixels[20 * 200 + column] = page }

    let layers = try #require(PageLayers(image(pixels, width: 200, height: 80)))
    let backdrop = try bytes(layers.backdrop)

    #expect(backdrop[20 * 200 + 40] == sidebar)
    #expect(backdrop[20 * 200 + 150] == page)
  }

  @Test func flattensFaintDetailOntoTheBackdropAndKeepsItInContent() throws {
    let background: UInt32 = 0xFFFC_FCFC
    let faint: UInt32 = 0xFFF4_F4F4
    var pixels = [UInt32](repeating: background, count: 200 * 16)
    for row in 0..<16 {
      for column in 60..<120 { pixels[row * 200 + column] = faint }
    }

    let layers = try #require(PageLayers(image(pixels, width: 200, height: 16)))
    let content = try bytes(layers.content)
    let backdrop = try bytes(layers.backdrop)

    #expect(content[10] == 0)
    #expect(content[90] == faint)
    #expect(backdrop[90] == background)
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
