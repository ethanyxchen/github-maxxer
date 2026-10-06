import AppKit
import SwiftUI

enum Palette {
  static let background = dynamic(light: 0xE2E3E0, dark: 0x111311)
  static let panel = dynamic(light: 0xF1F2EF, dark: 0x1A1C1A)
  static let sidebar = dynamic(light: 0xDCDED9, dark: 0x141614)
  static let ink = dynamic(light: 0x141714, dark: 0xEBEEE9)
  static let secondary = dynamic(light: 0x5C615B, dark: 0x8C928A)
  static let rule = dynamic(light: 0xC1C5BE, dark: 0x2E322E)
  static let empty = dynamic(light: 0xD2D5CF, dark: 0x292D29)
  static let reached = dynamic(light: 0x3FAE62, dark: 0x2F9E55)
  static let over = dynamic(light: 0x0E6B35, dark: 0x7CF0A2)
  private static let accents = [
    dynamic(light: 0x3D6FD9, dark: 0x6E9BFF),
    dynamic(light: 0xD9822B, dark: 0xF0A050),
    dynamic(light: 0x8A5CD1, dark: 0xB28CFF),
    dynamic(light: 0x1C9A9A, dark: 0x4FD1D1),
    dynamic(light: 0xD0476E, dark: 0xFF7A9C),
    dynamic(light: 0xA88A1E, dark: 0xD9BC4A),
  ]

  static func share(_ index: Int) -> Color {
    index == 0 ? ink : accents[(index - 1) % accents.count]
  }

  private static func dynamic(light: UInt32, dark: UInt32) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        NSColor(hex: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)
      })
  }
}

extension NSColor {
  convenience init(hex: UInt32) {
    self.init(
      srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
  }
}

extension Font {
  static func readout(_ size: CGFloat) -> Font {
    .system(size: size, weight: .medium, design: .monospaced)
  }
}

struct Eyebrow: View {
  let text: String

  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text.uppercased())
      .font(.system(size: 10.5, weight: .medium, design: .monospaced))
      .tracking(1.2)
      .foregroundStyle(Palette.secondary)
  }
}

struct PageTitle: View {
  let title: String

  init(_ title: String) { self.title = title }

  var body: some View {
    Text(title).font(.system(size: 22, weight: .bold)).foregroundStyle(Palette.ink)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct Rule: View {
  var vertical = false

  var body: some View {
    Palette.rule.frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
  }
}

struct Lamp: View {
  let isOn: Bool

  var body: some View {
    Circle()
      .fill(isOn ? Palette.reached : Palette.empty)
      .frame(width: 7, height: 7)
      .shadow(color: isOn ? Palette.reached : .clear, radius: 3)
  }
}

struct MeterShare: Identifiable {
  let id: AnyHashable
  let title: String
  let count: Int
  let target: Int
  let color: Color
}

struct SegmentMeter: View {
  let count: Int
  let target: Int
  var pace: Int?
  var shares: [MeterShare] = []
  var height: CGFloat = 18

  private var scale: Int { max(target, count) }
  private var segments: Int { max(1, min(scale, 60)) }
  private var perSegment: Double { Double(scale) / Double(segments) }
  private var isShared: Bool { shares.count > 1 }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      bar
      if isShared { legend }
    }
    .accessibilityHidden(true)
  }

  private var bar: some View {
    HStack(spacing: segments > 30 ? 2 : 3) {
      ForEach(0..<segments, id: \.self) { index in
        RoundedRectangle(cornerRadius: 1).fill(color(end: Double(index + 1) * perSegment))
      }
    }
    .frame(height: height)
    .overlay {
      if let pace, scale > 0 {
        GeometryReader { geometry in
          Triangle().fill(Palette.ink)
            .frame(width: 8, height: 5)
            .position(
              x: geometry.size.width * Double(pace) / Double(scale), y: geometry.size.height + 6)
        }
      }
    }
  }

  private var legend: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 140), spacing: 16, alignment: .leading)],
      alignment: .leading, spacing: 6
    ) {
      ForEach(shares) { share in
        HStack(spacing: 6) {
          RoundedRectangle(cornerRadius: 1).fill(share.color).frame(width: 8, height: 8)
          Text("\(share.title) \(share.count)/\(share.target)").lineLimit(1)
        }
        .help("\(share.title): \(share.count) of \(share.target)")
      }
    }
    .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Palette.secondary)
  }

  private func color(end: Double) -> Color {
    guard Double(count) >= end - 0.001 else { return Palette.empty }
    if isShared { return shareColor(at: end - perSegment / 2) }
    if end > Double(target) + 0.001 { return Palette.over }
    return count >= target ? Palette.reached : Palette.ink
  }

  private func shareColor(at position: Double) -> Color {
    var end = 0.0
    for share in shares {
      end += Double(share.count)
      if position < end { return share.color }
    }
    return Palette.empty
  }
}

private struct Triangle: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      path.move(to: CGPoint(x: rect.midX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
      path.closeSubpath()
    }
  }
}
