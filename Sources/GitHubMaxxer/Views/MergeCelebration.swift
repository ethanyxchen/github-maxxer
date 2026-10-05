import SwiftUI

enum Slam {
  static let hits = [0.55, 1.15, 1.8]
  static let impact = hits[2]
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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    if !reduceMotion {
      Choreography(landing: landing, duration: Glass.duration) { time in
        Glass(time: time, seed: seed)
        if time < Swing.timeline.duration {
          let swing = Swing.timeline.value(time: time)
          Sledgehammer(swing: swing).opacity(swing.opacity)
        }
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
  }

  private var seed: Int {
    landing.map { Int($0.date.timeIntervalSince1970 * 1000) % 9973 } ?? 0
  }
}

private struct Glass: View {
  private static let rings = [
    0.01, 0.022, 0.04, 0.065, 0.1, 0.15, 0.22, 0.31, 0.43, 0.58, 0.78, 1.15,
  ]
  private static let reaches = [0.12, 0.3, 1.15]
  private static let growths = [0.1, 0.12, 0.3]
  private static let shatter = Slam.impact + 0.08
  private static let fall = 0.9
  static let duration = shatter + 0.5 + fall
  let time: Double
  let seed: Int

  var body: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height * Slam.impactHeight)
      let reach = hypot(
        max(center.x, size.width - center.x), max(center.y, size.height - center.y))
      let web = Web(center: center, reach: reach, seed: seed)
      for hit in Slam.hits where time >= hit && time < hit + 0.2 {
        let fade = 1 - (time - hit) / 0.2
        let radius = min(size.width, size.height) * 0.12
        context.fill(
          Path(
            ellipseIn: CGRect(
              x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
          with: .radialGradient(
            Gradient(colors: [.white.opacity(fade), .clear]), center: center, startRadius: 0,
            endRadius: radius))
      }
      if time < Self.shatter {
        web.cracks(in: &context, extent: extent * reach)
      } else {
        web.shards(in: &context, time: time - Self.shatter)
      }
    }
  }

  private var extent: Double {
    Slam.hits.indices.reduce(0) { extent, hit in
      let progress = min(max((time - Slam.hits[hit]) / Self.growths[hit], 0), 1)
      return extent + (Self.reaches[hit] - extent) * (1 - pow(1 - progress, 2))
    }
  }

  private struct Web {
    let center: CGPoint
    let reach: Double
    let seed: Int

    var spokes: Int { 12 + Int(random(0, 9) * 6) }

    func random(_ index: Int, _ salt: Int) -> Double { noise(index + seed, salt) }

    func vertex(_ spoke: Int, _ ring: Int) -> CGPoint {
      guard ring >= 0 else { return center }
      let spoke = spoke % spokes
      let angle =
        2 * .pi * (Double(spoke) + 0.6 * (random(spoke, 10) - 0.5)) / Double(spokes)
        + (random(spoke * 17 + ring, 12) - 0.5) * 0.12
      let radius = Glass.rings[ring] * reach * (0.8 + 0.4 * random(spoke * 31 + ring, 11))
      return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    func length(_ spoke: Int) -> Int {
      let spoke = spoke % spokes
      return Glass.rings.count - (random(spoke, 14) < 0.3 ? 1 + Int(random(spoke, 18) * 5) : 0)
    }

    func cracks(in context: inout GraphicsContext, extent: Double) {
      var path = Path()
      for spoke in 0..<spokes {
        path.move(to: center)
        for ring in 0..<length(spoke) {
          let start = vertex(spoke, ring - 1)
          let end = vertex(spoke, ring)
          let from = distance(start)
          let to = distance(end)
          guard extent > from else { break }
          let progress = min((extent - from) / (to - from), 1)
          let kink = jag(start, end, salt: spoke * 13 + ring)
          if progress > 0.5 { path.addLine(to: kink) }
          let (anchor, share) = progress > 0.5 ? (kink, progress * 2 - 1) : (start, progress * 2)
          let target = progress > 0.5 ? end : kink
          path.addLine(
            to: CGPoint(
              x: anchor.x + (target.x - anchor.x) * share,
              y: anchor.y + (target.y - anchor.y) * share))
        }
        for ring in 0..<min(length(spoke), length(spoke + 1))
        where random(spoke * 7 + ring, 13) > 0.1 + 0.1 * Double(ring) {
          let start = vertex(spoke, ring)
          let end = vertex(spoke + 1, ring)
          guard extent >= max(distance(start), distance(end)) else { continue }
          path.move(to: start)
          path.addQuadCurve(
            to: end,
            control: CGPoint(
              x: center.x + ((start.x + end.x) / 2 - center.x) * 0.92,
              y: center.y + ((start.y + end.y) / 2 - center.y) * 0.92))
        }
      }
      context.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 2.4)
      context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 1)
    }

    func shards(in context: inout GraphicsContext, time: Double) {
      for spoke in 0..<spokes {
        for ring in 0..<min(length(spoke), length(spoke + 1)) {
          let corners = [
            vertex(spoke, ring - 1), vertex(spoke, ring), vertex(spoke + 1, ring),
            vertex(spoke + 1, ring - 1),
          ]
          let delay = 0.25 * random(spoke * 5 + ring, 15) + 0.03 * Double(ring)
          let progress = min(max((time - delay) / Glass.fall, 0), 1)
          guard progress < 1 else { continue }
          let middle = CGPoint(
            x: corners.map(\.x).reduce(0, +) / 4, y: corners.map(\.y).reduce(0, +) / 4)
          var shard = Path()
          shard.addLines(corners)
          shard.closeSubpath()
          var piece = context
          piece.opacity = 1 - progress
          piece.translateBy(
            x: middle.x + (middle.x - center.x) * 0.5 * progress,
            y: middle.y + reach * 0.9 * progress * progress)
          piece.rotate(by: .radians((random(spoke * 3 + ring, 16) - 0.5) * 3 * progress))
          piece.scaleBy(x: 1 - 0.5 * progress, y: 1 - 0.5 * progress)
          piece.translateBy(x: -middle.x, y: -middle.y)
          piece.fill(shard, with: .color(.white.opacity(0.14)))
          piece.stroke(shard, with: .color(.black.opacity(0.3)), lineWidth: 2.2)
          piece.stroke(shard, with: .color(.white.opacity(0.9)), lineWidth: 1)
        }
      }
    }

    private func jag(_ start: CGPoint, _ end: CGPoint, salt: Int) -> CGPoint {
      let offset = (random(salt, 17) - 0.5) * 0.35
      return CGPoint(
        x: (start.x + end.x) / 2 - (end.y - start.y) * offset,
        y: (start.y + end.y) / 2 + (end.x - start.x) * offset)
    }

    private func distance(_ point: CGPoint) -> Double {
      hypot(point.x - center.x, point.y - center.y)
    }
  }
}

struct SlamShake: ViewModifier {
  @MainActor private static let timeline = KeyframeTimeline(initialValue: 0.0) {
    KeyframeTrack {
      LinearKeyframe(0, duration: Slam.hits[0])
      LinearKeyframe(7, duration: 0.04)
      CubicKeyframe(-4, duration: 0.07)
      CubicKeyframe(0, duration: 0.08)
      LinearKeyframe(0, duration: Slam.hits[1] - Slam.hits[0] - 0.19)
      LinearKeyframe(11, duration: 0.04)
      CubicKeyframe(-6, duration: 0.07)
      CubicKeyframe(0, duration: 0.08)
      LinearKeyframe(0, duration: Slam.hits[2] - Slam.hits[1] - 0.19)
      LinearKeyframe(20, duration: 0.04)
      CubicKeyframe(-12, duration: 0.07)
      CubicKeyframe(7, duration: 0.07)
      CubicKeyframe(-3, duration: 0.07)
      CubicKeyframe(0, duration: 0.09)
    }
  }
  let landing: Landing?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    Choreography(landing: landing, duration: Self.timeline.duration) { time in
      content.offset(y: reduceMotion ? 0 : Self.timeline.value(time: time))
    }
  }
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
  private static let sweepStart = Slam.impact + 0.8
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
