import SwiftUI

enum Slam {
  static let impact = 0.55
  static let shatter = impact + 0.45
  static let reveal = 2.5
  static let impactHeight = 0.55
}

struct Choreography<Content: View>: View {
  let landing: Landing?
  let duration: Double
  @ViewBuilder let content: (Double) -> Content
  @State private var isSettled = false

  private var start: Date { landing?.date ?? .distantPast }

  var body: some View {
    TimelineView(.animation(paused: isSettled)) { context in
      content(isSettled ? duration : min(context.date.timeIntervalSince(start), duration))
    }
    .task(id: landing) {
      isSettled = false
      let remaining = start.addingTimeInterval(duration).timeIntervalSinceNow
      try? await Task.sleep(for: .seconds(max(0, remaining)))
      isSettled = true
    }
  }
}

struct HammerSlam: View {
  let landing: Landing?
  @State private var page: (landing: Landing, layers: PageLayers)?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    if !reduceMotion {
      Choreography(landing: landing, duration: Shatter.duration) { time in
        Shatter(
          time: time, seed: seed, layers: page.flatMap { $0.landing == landing ? $0.layers : nil })
        if time > Swing.entrance, time < Swing.timeline.duration {
          let swing = Swing.timeline.value(time: time)
          Sledgehammer(swing: swing).opacity(swing.opacity)
        }
      }
      .background {
        PageCapture(landing: landing) { landing, layers in page = (landing, layers) }
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
  }

  private var seed: Int {
    landing.map { Int($0.date.timeIntervalSince1970 * 1000) % 9973 } ?? 0
  }
}

private struct PageCapture: NSViewRepresentable {
  let landing: Landing?
  let capture: (Landing, PageLayers) -> Void

  func makeNSView(context: Context) -> NSView { NSView() }

  func updateNSView(_ view: NSView, context: Context) {
    guard let landing, landing != context.coordinator.landing else { return }
    context.coordinator.landing = landing
    DispatchQueue.main.async {
      guard let content = view.window?.contentView else { return }
      let frame = view.convert(view.bounds, to: content)
      guard let bitmap = content.bitmapImageRepForCachingDisplay(in: frame) else { return }
      content.cacheDisplay(in: frame, to: bitmap)
      guard let page = bitmap.cgImage, let layers = PageLayers(page) else { return }
      capture(landing, layers)
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator {
    var landing: Landing?
  }
}

private struct Shatter: View {
  static let rings = [0.01, 0.022, 0.04, 0.065, 0.1, 0.15, 0.22, 0.31, 0.43, 0.58, 0.78, 1.15]
  private static let growth = 0.18
  private static let fall = 0.9
  private static let fade = 0.35
  static let duration = Slam.reveal + fade
  @MainActor private static let shake = KeyframeTimeline(initialValue: 0.0) {
    KeyframeTrack {
      LinearKeyframe(0, duration: Slam.impact)
      LinearKeyframe(20, duration: 0.04)
      CubicKeyframe(-12, duration: 0.07)
      CubicKeyframe(7, duration: 0.07)
      CubicKeyframe(-3, duration: 0.07)
      CubicKeyframe(0, duration: 0.09)
    }
  }
  let time: Double
  let seed: Int
  let layers: PageLayers?

  var body: some View {
    Canvas { context, size in
      let bounds = CGRect(origin: .zero, size: size)
      let center = CGPoint(x: size.width / 2, y: size.height * Slam.impactHeight)
      let reach = hypot(
        max(center.x, size.width - center.x), max(center.y, size.height - center.y))
      let web = Web(center: center, reach: reach, seed: seed)
      guard let layers, time >= Slam.impact else { return }
      let growth = min(max((time - Slam.impact) / Self.growth, 0), 1)
      context.translateBy(x: 0, y: Self.shake.value(time: time))
      var backdrop = context
      backdrop.opacity = 1 - min(max((time - Slam.reveal) / Self.fade, 0), 1)
      backdrop.draw(context.resolve(Image(decorative: layers.backdrop, scale: 1)), in: bounds)
      web.shards(
        in: &context, time: time - Slam.shatter, fall: Self.fall,
        extent: reach * Self.rings.last! * (1 - pow(1 - growth, 3)),
        content: context.resolve(Image(decorative: layers.content, scale: 1)), bounds: bounds)
      flash(in: &context, at: center, radius: min(size.width, size.height) * 0.14)
    }
  }

  private func flash(in context: inout GraphicsContext, at center: CGPoint, radius: Double) {
    let fade = 1 - (time - Slam.impact) / 0.25
    guard fade > 0, fade <= 1 else { return }
    context.fill(
      Path(
        ellipseIn: CGRect(
          x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
      with: .radialGradient(
        Gradient(colors: [.white.opacity(fade), .clear]), center: center, startRadius: 0,
        endRadius: radius))
  }
}

private struct Web {
  let center: CGPoint
  let reach: Double
  let seed: Int

  private var spokes: Int { 12 + Int(random(0, 9) * 6) }

  func shards(
    in context: inout GraphicsContext, time: Double, fall: Double,
    extent: Double, content: GraphicsContext.ResolvedImage, bounds: CGRect
  ) {
    for ring in (0..<Shatter.rings.count).reversed() {
      for spoke in 0..<spokes {
        let delay =
          0.3 * Double(ring) / Double(Shatter.rings.count) + 0.12 * random(spoke * 5 + ring, 15)
        let progress = min(max((time - delay) / fall, 0), 1)
        guard progress < 1 else { continue }
        var shard = Path()
        shard.addLines([
          vertex(spoke, ring - 1), kink(spoke, ring), vertex(spoke, ring),
          vertex(spoke + 1, ring), kink(spoke + 1, ring), vertex(spoke + 1, ring - 1),
        ])
        shard.closeSubpath()
        let middle = shard.boundingRect
        let crack = extent >= distance(vertex(spoke, ring - 1)) ? 1.0 : 0
        let drift = crack * (2 + 4 * random(spoke * 11 + ring, 19)) / max(distance(middle.mid), 1)
        var piece = context
        piece.opacity = 1 - pow(progress, 2)
        piece.translateBy(
          x: middle.midX + (middle.midX - center.x) * drift,
          y: middle.midY + (middle.midY - center.y) * drift + reach * 0.6 * progress * progress)
        piece.rotate(
          by: .radians(
            (random(spoke * 3 + ring, 16) - 0.5) * (1.4 * progress + 0.02 * crack)))
        piece.scaleBy(x: 1 - 0.4 * progress, y: 1 - 0.4 * progress)
        piece.translateBy(x: -middle.midX, y: -middle.midY)
        piece.clip(to: shard)
        piece.draw(content, in: bounds)
      }
    }
  }

  private func random(_ index: Int, _ salt: Int) -> Double { noise(index + seed, salt) }

  private func vertex(_ spoke: Int, _ ring: Int) -> CGPoint {
    guard ring >= 0 else { return center }
    let spoke = spoke % spokes
    let angle =
      2 * .pi * (Double(spoke) + 0.6 * (random(spoke, 10) - 0.5)) / Double(spokes)
      + (random(spoke * 17 + ring, 12) - 0.5) * 0.12
    let radius = Shatter.rings[ring] * reach * (0.8 + 0.4 * random(spoke * 31 + ring, 11))
    return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
  }

  private func kink(_ spoke: Int, _ ring: Int) -> CGPoint {
    let start = vertex(spoke, ring - 1)
    let end = vertex(spoke, ring)
    let offset = (random((spoke % spokes) * 13 + ring, 17) - 0.5) * 0.35
    return CGPoint(
      x: (start.x + end.x) / 2 - (end.y - start.y) * offset,
      y: (start.y + end.y) / 2 + (end.x - start.x) * offset)
  }

  private func distance(_ point: CGPoint) -> Double {
    hypot(point.x - center.x, point.y - center.y)
  }
}

extension CGRect {
  fileprivate var mid: CGPoint { CGPoint(x: midX, y: midY) }
}

struct MergedStamp: View {
  let landing: Landing

  var body: some View {
    Choreography(landing: landing, duration: StampScene.duration) { time in
      StampScene(time: time)
    }
  }
}

private struct StampScene: View {
  private static let sweepStart = Slam.reveal + 0.5
  private static let sweepDuration = 0.45
  private static let sparkleLife = 0.8
  static let duration = sweepStart + sweepDuration + sparkleLife
  let time: Double

  var body: some View {
    let time = time - Self.sweepStart
    HStack(spacing: 4) {
      Text("Merged")
      Image(systemName: "checkmark")
    }
    .font(.system(size: 11, weight: .medium, design: .monospaced))
    .foregroundStyle(Palette.reached)
    .mask {
      Rectangle().scaleEffect(x: min(max(time / Self.sweepDuration, 0), 1), anchor: .leading)
    }
    .overlay {
      Canvas { context, size in sparkles(in: &context, size: size, time: time) }
        .padding(-16)
    }
  }

  private func sparkles(in context: inout GraphicsContext, size: CGSize, time: Double) {
    let count = 16
    for sparkle in 0..<count {
      let spawn = Double(sparkle) / Double(count)
      let age = (time - spawn * Self.sweepDuration) / Self.sparkleLife
      guard age >= 0, age < 1 else { continue }
      let drift = 1 - pow(1 - age, 2)
      let x = 16 + spawn * (size.width - 32) + (noise(sparkle, 6) - 0.5) * 16 * drift
      let y =
        size.height / 2 + (noise(sparkle, 7) - 0.5) * 10 + (8 + 14 * noise(sparkle, 8)) * drift
      let radius = (2 + 2.5 * noise(sparkle, 9)) * (1 - age)
      context.fill(
        Sparkle().path(
          in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
        with: .color(Palette.reached.opacity(1 - age)))
    }
  }
}

private struct Sparkle: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      let center = CGPoint(x: rect.midX, y: rect.midY)
      let pinch = rect.width * 0.12
      path.move(to: CGPoint(x: center.x, y: rect.minY))
      path.addQuadCurve(
        to: CGPoint(x: rect.maxX, y: center.y), control: center.offsetBy(pinch, -pinch))
      path.addQuadCurve(
        to: CGPoint(x: center.x, y: rect.maxY), control: center.offsetBy(pinch, pinch))
      path.addQuadCurve(
        to: CGPoint(x: rect.minX, y: center.y), control: center.offsetBy(-pinch, pinch))
      path.addQuadCurve(
        to: CGPoint(x: center.x, y: rect.minY), control: center.offsetBy(-pinch, -pinch))
    }
  }
}

func noise(_ index: Int, _ salt: Int) -> Double {
  let value = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43_758.5453
  return value - floor(value)
}

extension CGPoint {
  fileprivate func offsetBy(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
    CGPoint(x: x + dx, y: y + dy)
  }
}
