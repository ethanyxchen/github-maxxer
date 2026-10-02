import AppKit
import SwiftUI

enum Palette {
  static let background = dynamic(light: 0xE2E3E0, dark: 0x111311)
  static let panel = dynamic(light: 0xF1F2EF, dark: 0x1A1C1A)
  static let ink = dynamic(light: 0x141714, dark: 0xEBEEE9)
  static let secondary = dynamic(light: 0x5C615B, dark: 0x8C928A)
  static let rule = dynamic(light: 0xC1C5BE, dark: 0x2E322E)
  static let empty = dynamic(light: 0xD2D5CF, dark: 0x292D29)
  static let reached = dynamic(light: 0x3FAE62, dark: 0x2F9E55)
  static let over = dynamic(light: 0x0E6B35, dark: 0x7CF0A2)

  static func fill(count: Int, target: Int) -> Color {
    switch count {
    case 0: empty
    case ..<target: secondary.opacity(0.35)
    case target: reached
    default: over
    }
  }

  private static func dynamic(light: UInt32, dark: UInt32) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        return NSColor(
          srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
          blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
      })
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

struct SegmentMeter: View {
  let count: Int
  let target: Int
  let scale: Int
  var pace: Int?
  var height: CGFloat = 18

  private var segments: Int { max(1, min(scale, 60)) }

  var body: some View {
    let perSegment = Double(scale) / Double(segments)
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
    .accessibilityHidden(true)
  }

  private func color(end: Double) -> Color {
    guard Double(count) >= end - 0.001 else { return Palette.empty }
    if end > Double(target) + 0.001 { return Palette.over }
    return count >= target ? Palette.reached : Palette.ink
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
