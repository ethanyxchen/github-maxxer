import SwiftUI

enum Slam {
  static let impact = 0.57
  static let rest = -60.0
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
      Choreography(landing: landing, duration: Swing.timeline.duration) { time in
        SlamScene(swing: Swing.timeline.value(time: time))
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
  }
}

private struct SlamScene: View {
  let swing: Swing

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let length = min(size.height * 0.95, size.width * 0.7)
      let target = CGPoint(x: size.width * 0.55, y: size.height * 0.6)
      let face = CGPoint(
        x: -length * Hammer.headWidth / 2, y: -length * (1 - Hammer.headHeight / 2)
      )
      .rotated(by: Slam.rest)
      let pivot = CGPoint(x: target.x - face.x, y: target.y - face.y)
      ZStack {
        Impact(progress: swing.shock, at: target, reach: size.width)
        ForEach([2, 1, 0], id: \.self) { ghost in
          Hammer(length: length)
            .rotationEffect(
              .degrees(swing.angle + Double(ghost) * 9 * swing.trail), anchor: .bottom
            )
            .position(x: pivot.x, y: pivot.y - length / 2)
            .opacity(ghost == 0 ? swing.opacity : 0.22 * swing.trail / Double(ghost))
        }
      }
    }
  }
}

private struct Swing {
  var angle = 25.0
  var opacity = 0.0
  var trail = 0.0
  var shock = 0.0

  @MainActor static let timeline = KeyframeTimeline(initialValue: Swing()) {
    KeyframeTrack(\.angle) {
      MoveKeyframe(25)
      CubicKeyframe(-20, duration: 0.32)
      CubicKeyframe(-12, duration: 0.12)
      LinearKeyframe(Slam.rest, duration: 0.13, timingCurve: .easeIn)
      CubicKeyframe(Slam.rest + 4, duration: 0.06)
      CubicKeyframe(Slam.rest, duration: 0.08)
      LinearKeyframe(Slam.rest, duration: 0.35)
      CubicKeyframe(25, duration: 0.4)
    }
    KeyframeTrack(\.opacity) {
      MoveKeyframe(1)
      LinearKeyframe(1, duration: Slam.impact + 0.69)
      LinearKeyframe(0, duration: 0.2)
    }
    KeyframeTrack(\.trail) {
      MoveKeyframe(0)
      LinearKeyframe(0, duration: Slam.impact - 0.13)
      LinearKeyframe(1, duration: 0.09)
      LinearKeyframe(0, duration: 0.06)
    }
    KeyframeTrack(\.shock) {
      MoveKeyframe(0)
      LinearKeyframe(0, duration: Slam.impact)
      LinearKeyframe(1, duration: 0.8)
    }
  }
}

private struct Hammer: View {
  static let headWidth = 0.42
  static let headHeight = 0.17
  let length: CGFloat

  var body: some View {
    let width = length * Self.headWidth
    let height = length * Self.headHeight
    let handle = length * 0.075
    ZStack(alignment: .top) {
      VStack(spacing: 0) {
        LinearGradient(
          colors: [Color(hex: 0xA86A35), Color(hex: 0xE9B676), Color(hex: 0xC98B4F)],
          startPoint: .leading, endPoint: .trailing
        )
        .frame(width: handle)
        VStack(spacing: handle * 0.32) {
          ForEach(0..<9, id: \.self) { _ in
            Color.black.opacity(0.25).frame(height: handle * 0.12)
          }
        }
        .padding(.vertical, handle * 0.4)
        .frame(width: handle * 1.2, height: length * 0.28)
        .background(
          LinearGradient(
            colors: [Color(hex: 0x1F7A40), Color(hex: 0x3FAE62), Color(hex: 0x1F7A40)],
            startPoint: .leading, endPoint: .trailing),
          in: RoundedRectangle(cornerRadius: handle * 0.5))
      }
      .padding(.top, height * 0.6)
      HammerHead()
        .fill(
          LinearGradient(
            colors: [Color(hex: 0xC4C9CE), Color(hex: 0x6C7278), Color(hex: 0x2B2F33)],
            startPoint: .top, endPoint: .bottom)
        )
        .overlay {
          HammerHead().stroke(.white.opacity(0.35), lineWidth: 1.5)
        }
        .frame(height: height)
      RoundedRectangle(cornerRadius: height * 0.08)
        .fill(
          LinearGradient(
            colors: [Color(hex: 0xE3E7EA), Color(hex: 0x80868C), Color(hex: 0x3A3F44)],
            startPoint: .top, endPoint: .bottom)
        )
        .frame(width: width * 0.16, height: height * 1.16)
        .offset(y: -height * 0.08)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(width: width, height: length)
    .shadow(color: .black.opacity(0.35), radius: length * 0.03, y: length * 0.02)
  }
}

private struct HammerHead: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      let neck = rect.minX + rect.width * 0.14
      path.move(to: CGPoint(x: neck, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.18))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.18))
      path.addLine(to: CGPoint(x: neck, y: rect.maxY))
      path.closeSubpath()
    }
  }
}

private struct Impact: View {
  let progress: Double
  let at: CGPoint
  let reach: CGFloat

  var body: some View {
    Canvas { context, _ in
      guard progress > 0, progress < 1 else { return }
      let fade = 1 - progress
      let spread = 1 - pow(fade, 3)
      let flash = reach * 0.18
      context.fill(
        Path(
          ellipseIn: CGRect(x: at.x - flash, y: at.y - flash, width: flash * 2, height: flash * 2)
        ),
        with: .radialGradient(
          Gradient(colors: [.white.opacity(fade * fade), .clear]), center: at, startRadius: 0,
          endRadius: flash))
      for (delay, weight) in [(0.0, 7.0), (0.18, 4.0)] {
        let wave = max(0, (progress - delay) / (1 - delay))
        let width = reach * 0.75 * (1 - pow(1 - wave, 3))
        context.stroke(
          Path(
            ellipseIn: CGRect(
              x: at.x - width / 2, y: at.y - width * 0.14, width: width, height: width * 0.28)),
          with: .color(Palette.ink.opacity(0.35 * (1 - wave))), lineWidth: weight * (1 - wave))
      }
      for line in 0..<12 {
        let angle = Double(line) / 12 * 2 * .pi + noise(line, 1) * 0.3
        let inner = reach * (0.04 + 0.1 * spread)
        let outer = inner + reach * 0.06 * fade
        var path = Path()
        path.move(to: CGPoint(x: at.x + cos(angle) * inner, y: at.y + sin(angle) * inner * 0.6))
        path.addLine(to: CGPoint(x: at.x + cos(angle) * outer, y: at.y + sin(angle) * outer * 0.6))
        context.stroke(path, with: .color(Palette.ink.opacity(fade)), lineWidth: 3 * fade)
      }
      for chip in 0..<22 {
        let angle = -.pi * (0.08 + 0.84 * noise(chip, 2))
        let speed = reach * (0.18 + 0.22 * noise(chip, 3))
        let x = at.x + cos(angle) * speed * progress
        let y = at.y + sin(angle) * speed * progress + reach * 0.35 * progress * progress
        let size = 4 + 6 * noise(chip, 4)
        let color = chip.isMultiple(of: 3) ? Palette.ink : Palette.reached
        context.fill(
          Path(CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
            .applying(CGAffineTransform(rotationAngle: progress * 12 * noise(chip, 5)))
            .offsetBy(dx: x, dy: y),
          with: .color(color.opacity(fade)))
      }
    }
  }
}

struct SlamShake: ViewModifier {
  @MainActor private static let timeline = KeyframeTimeline(initialValue: 0.0) {
    KeyframeTrack {
      LinearKeyframe(0, duration: Slam.impact)
      LinearKeyframe(18, duration: 0.04)
      CubicKeyframe(-11, duration: 0.07)
      CubicKeyframe(6, duration: 0.07)
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

private func noise(_ index: Int, _ salt: Int) -> Double {
  let value = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43_758.5453
  return value - floor(value)
}

extension CGPoint {
  fileprivate func rotated(by degrees: Double) -> CGPoint {
    let radians = degrees * .pi / 180
    return CGPoint(
      x: x * cos(radians) - y * sin(radians), y: x * sin(radians) + y * cos(radians))
  }

  fileprivate func offsetBy(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
    CGPoint(x: x + dx, y: y + dy)
  }
}
