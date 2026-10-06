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
  var title: String?
  let count: Int
  let target: Int
  var pace: Int?

  var scale: Int { max(target, count) }
}

struct SegmentMeter: View {
  let shares: [MeterShare]
  var height: CGFloat = 18

  init(count: Int, target: Int, pace: Int? = nil, height: CGFloat = 18) {
    self.init(
      shares: [MeterShare(id: "", count: count, target: target, pace: pace)], height: height)
  }

  init(shares: [MeterShare], height: CGFloat = 18) {
    let visible = shares.filter { $0.scale > 0 }
    self.shares = visible.isEmpty ? Array(shares.prefix(1)) : visible
    self.height = height
  }

  private var total: Int { shares.map(\.scale).reduce(0, +) }
  private var segments: Int { max(1, min(total, 60)) }

  var body: some View {
    let spacing: CGFloat = segments > 30 ? 2 : 3
    ProportionalStack(weights: shares.map { max($0.scale, 1) }, spacing: spacing * 4) {
      ForEach(shares) { share in
        VStack(alignment: .leading, spacing: 12) {
          ShareBar(
            share: share,
            segments: max(
              1, Int((Double(segments * share.scale) / Double(max(total, 1))).rounded())),
            spacing: spacing, height: height)
          if let title = share.title {
            Text("\(title) \(share.count)/\(share.target)")
              .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Palette.secondary)
              .lineLimit(1).help("\(title): \(share.count) of \(share.target)")
          }
        }
      }
    }
    .accessibilityHidden(true)
  }
}

private struct ShareBar: View {
  let share: MeterShare
  let segments: Int
  let spacing: CGFloat
  let height: CGFloat

  var body: some View {
    let perSegment = Double(share.scale) / Double(segments)
    HStack(spacing: spacing) {
      ForEach(0..<segments, id: \.self) { index in
        RoundedRectangle(cornerRadius: 1).fill(color(end: Double(index + 1) * perSegment))
      }
    }
    .frame(height: height)
    .overlay {
      if let pace = share.pace, share.scale > 0 {
        GeometryReader { geometry in
          Triangle().fill(Palette.ink)
            .frame(width: 8, height: 5)
            .position(
              x: geometry.size.width * Double(pace) / Double(share.scale),
              y: geometry.size.height + 6)
        }
      }
    }
  }

  private func color(end: Double) -> Color {
    guard Double(share.count) >= end - 0.001 else { return Palette.empty }
    if end > Double(share.target) + 0.001 { return Palette.over }
    return share.count >= share.target ? Palette.reached : Palette.ink
  }
}

private struct ProportionalStack: Layout {
  let weights: [Int]
  let spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let widths = self.widths(proposal.width ?? 0)
    let height = zip(subviews, widths).map {
      $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height
    }.max()
    return CGSize(width: proposal.width ?? 0, height: height ?? 0)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var x = bounds.minX
    for (subview, width) in zip(subviews, widths(bounds.width)) {
      subview.place(
        at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: nil))
      x += width + spacing
    }
  }

  private func widths(_ width: CGFloat) -> [CGFloat] {
    let available = max(width - spacing * CGFloat(weights.count - 1), 0)
    let total = CGFloat(weights.reduce(0, +))
    return weights.map { available * CGFloat($0) / total }
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
