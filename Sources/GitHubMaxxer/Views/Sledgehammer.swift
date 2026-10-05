import SceneKit
import SwiftUI

struct Swing {
  static let entrance = 0.05
  var angle = 40.0
  var opacity = 0.0

  @MainActor static let timeline = KeyframeTimeline(initialValue: Swing()) {
    KeyframeTrack(\.angle) {
      MoveKeyframe(40)
      CubicKeyframe(32, duration: 0.3)
      LinearKeyframe(0, duration: Slam.impact - 0.3, timingCurve: .easeIn)
      CubicKeyframe(5, duration: 0.1)
      CubicKeyframe(0, duration: 0.1)
      LinearKeyframe(0, duration: 0.15)
      CubicKeyframe(40, duration: 0.3)
    }
    KeyframeTrack(\.opacity) {
      MoveKeyframe(0)
      LinearKeyframe(0, duration: entrance)
      LinearKeyframe(1, duration: 0.1)
      LinearKeyframe(1, duration: Slam.impact + 0.25)
      LinearKeyframe(0, duration: 0.25)
    }
  }
}

struct Sledgehammer: NSViewRepresentable {
  let swing: Swing

  func makeNSView(context: Context) -> SCNView {
    let view = SCNView(frame: .zero)
    view.scene = context.coordinator.scene
    view.backgroundColor = .clear
    view.antialiasingMode = .multisampling4X
    return view
  }

  func updateNSView(_ view: SCNView, context: Context) {
    context.coordinator.pose(swing)
  }

  func makeCoordinator() -> SledgehammerRig { SledgehammerRig() }
}

@MainActor
final class SledgehammerRig {
  private static let handleLength: Float = 5.2
  private static let headLength: Float = 2.1
  private static let glassDistance: Float = 7
  private static let cameraDistance: Float = 12
  private static let fieldOfView: Float = 38

  let scene = SCNScene()
  private let rig = SCNNode()
  private let swinging = SCNNode()

  init() {
    let orientation =
      simd_quatf(angle: 0.6, axis: [0, 0, 1]) * simd_quatf(angle: 0.45, axis: [0, 1, 0])
      * simd_quatf(angle: -0.25, axis: [1, 0, 0])
    let visibleHeight = 2 * Self.glassDistance * tan(Self.fieldOfView / 2 * .pi / 180)
    let glass = Self.cameraDistance - Self.glassDistance
    let face = SIMD3<Float>(0, -Float(Slam.impactHeight - 0.5) * visibleHeight, glass)
    rig.simdOrientation = orientation
    rig.simdPosition = face - orientation.act([0, Self.handleLength, -Self.headLength / 2])
    rig.addChildNode(swinging)
    for part in Self.hammer() { swinging.addChildNode(part) }
    scene.rootNode.addChildNode(rig)

    let camera = SCNNode()
    camera.camera = SCNCamera()
    camera.camera?.fieldOfView = CGFloat(Self.fieldOfView)
    camera.camera?.zNear = 0.05
    camera.simdPosition = [0, 0, Self.cameraDistance]
    scene.rootNode.addChildNode(camera)

    let catcher = SCNMaterial()
    catcher.lightingModel = .shadowOnly
    let screen = SCNNode(geometry: SCNPlane(width: 80, height: 80))
    screen.geometry?.materials = [catcher]
    screen.simdPosition = [0, 0, glass]
    scene.rootNode.addChildNode(screen)

    let sun = SCNLight()
    sun.type = .directional
    sun.intensity = 1000
    sun.castsShadow = true
    sun.shadowMode = .forward
    sun.shadowColor = NSColor(white: 0, alpha: 0.45)
    sun.shadowRadius = 14
    sun.shadowSampleCount = 24
    sun.shadowMapSize = CGSize(width: 4096, height: 4096)
    sun.automaticallyAdjustsShadowProjection = false
    sun.orthographicScale = 25
    let key = SCNNode()
    key.light = sun
    key.simdPosition = [0, 0, Self.cameraDistance]
    key.simdLook(at: [-3, -5, glass - 4])
    scene.rootNode.addChildNode(key)
    scene.lightingEnvironment.contents = Self.studio()
    scene.lightingEnvironment.intensity = 1.6
  }

  func pose(_ swing: Swing) {
    swinging.simdEulerAngles.x = Float(swing.angle * .pi / 180)
  }

  private static func hammer() -> [SCNNode] {
    let paint = material(
      texture { x, y in 0.025 + 0.02 * noise(x * 7919 + y, 21) }, metalness: 0.15,
      roughness: texture { x, y in 0.22 + 0.3 * noise(x * 6271 + y, 22) })
    paint.clearCoat.contents = 0.6
    paint.clearCoatRoughness.contents = 0.25
    let face = material(
      texture { x, y in
        0.42 + 0.05 * noise(Int(hypot(Double(x - 128), Double(y - 128)) * 2), 23)
          + 0.06 * noise(x * 977 + y, 26)
      }, metalness: 1, roughness: texture { x, y in 0.3 + 0.15 * noise(x * 3301 + y, 24) })
    let edge = material(NSColor(white: 0.62, alpha: 1), metalness: 1, roughness: 0.3)
    let rubber = material(
      texture { x, y in 0.035 + 0.02 * noise(x * 4409 + y, 25) }, metalness: 0, roughness: 0.82)
    let fiberglass = material(NSColor(hex: 0xF2B10A), metalness: 0, roughness: 0.35)
    fiberglass.clearCoat.contents = 1
    fiberglass.clearCoatRoughness.contents = 0.06

    let head = SCNShape(
      path: octagon(width: 1.05, cut: 0.24, radius: 0.07), extrusionDepth: CGFloat(headLength))
    head.chamferRadius = 0.07
    head.chamferMode = .both
    head.materials = [face, face, paint, edge, edge]
    let collar = SCNCone(topRadius: 0.25, bottomRadius: 0.17, height: 1.1)
    collar.materials = [rubber]
    let shaft = SCNCylinder(radius: 0.16, height: CGFloat(handleLength))
    shaft.materials = [fiberglass]
    let grip = SCNCylinder(radius: 0.19, height: 1.6)
    grip.materials = [rubber]
    let band = SCNCylinder(radius: 0.195, height: 0.14)
    band.materials = [fiberglass]
    let rib = SCNTorus(ringRadius: 0.19, pipeRadius: 0.018)
    rib.materials = [rubber]
    let knob = SCNSphere(radius: 0.25)
    knob.materials = [rubber]

    func node(_ geometry: SCNGeometry, y: Float, scale: SIMD3<Float> = [1, 1, 1]) -> SCNNode {
      let node = SCNNode(geometry: geometry)
      node.simdPosition = [0, y, 0]
      node.simdScale = scale
      return node
    }
    return [
      node(head, y: handleLength),
      node(collar, y: handleLength - 1.05),
      node(shaft, y: handleLength / 2),
      node(grip, y: 0.9),
      node(band, y: 1.55),
      node(knob, y: 0.08, scale: [1, 0.45, 1]),
    ] + stride(from: Float(0.3), through: 1.4, by: 0.16).map { node(rib, y: $0) }
  }

  private static func octagon(width: CGFloat, cut: CGFloat, radius: CGFloat) -> NSBezierPath {
    let half = width / 2
    let corners = [
      NSPoint(x: -half, y: -half + cut), NSPoint(x: -half + cut, y: -half),
      NSPoint(x: half - cut, y: -half), NSPoint(x: half, y: -half + cut),
      NSPoint(x: half, y: half - cut), NSPoint(x: half - cut, y: half),
      NSPoint(x: -half + cut, y: half), NSPoint(x: -half, y: half - cut),
    ]
    let path = NSBezierPath()
    path.move(to: NSPoint(x: -half, y: 0))
    for (index, corner) in corners.enumerated() {
      path.appendArc(from: corner, to: corners[(index + 1) % corners.count], radius: radius)
    }
    path.close()
    return path
  }

  private static func texture(_ value: (Int, Int) -> Double) -> CGImage {
    let size = 256
    let pixels = (0..<size * size).map { index in
      UInt8(min(max(value(index % size, index / size), 0), 1) * 255)
    }
    return CGImage(
      width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(),
      provider: CGDataProvider(data: Data(pixels) as CFData)!, decode: nil,
      shouldInterpolate: true, intent: .defaultIntent)!
  }

  private static func material(_ color: Any, metalness: CGFloat, roughness: Any) -> SCNMaterial {
    let material = SCNMaterial()
    material.lightingModel = .physicallyBased
    material.diffuse.contents = color
    material.metalness.contents = metalness
    material.roughness.contents = roughness
    return material
  }

  private static func studio() -> NSImage {
    NSImage(size: NSSize(width: 1024, height: 512), flipped: false) { rect in
      NSGradient(
        colors: [
          .init(white: 0.05, alpha: 1), .init(white: 0.18, alpha: 1), .init(white: 0.55, alpha: 1),
          .init(white: 0.85, alpha: 1),
        ],
        atLocations: [0, 0.45, 0.6, 1], colorSpace: .sRGB
      )?.draw(in: rect, angle: 90)
      NSColor.white.setFill()
      for softbox in [
        NSRect(x: 120, y: 360, width: 260, height: 90),
        NSRect(x: 620, y: 330, width: 160, height: 60),
        NSRect(x: 420, y: 470, width: 300, height: 30),
      ] {
        NSBezierPath(roundedRect: softbox, xRadius: 16, yRadius: 16).fill()
      }
      return true
    }
  }
}
