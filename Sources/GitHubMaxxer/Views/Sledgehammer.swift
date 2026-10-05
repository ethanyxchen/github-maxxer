import SceneKit
import SwiftUI

struct Swing {
  var angle = -85.0
  var drop = 0.0
  var opacity = 0.0

  @MainActor static let timeline = KeyframeTimeline(initialValue: Swing()) {
    KeyframeTrack(\.angle) {
      MoveKeyframe(-85)
      CubicKeyframe(-65, duration: 0.3)
      LinearKeyframe(0, duration: Slam.hits[0] - 0.3, timingCurve: .easeIn)
      CubicKeyframe(-25, duration: 0.15)
      CubicKeyframe(-60, duration: 0.2)
      LinearKeyframe(0, duration: Slam.hits[1] - Slam.hits[0] - 0.35, timingCurve: .easeIn)
      CubicKeyframe(-25, duration: 0.15)
      CubicKeyframe(-85, duration: 0.28)
      LinearKeyframe(0, duration: Slam.hits[2] - Slam.hits[1] - 0.43, timingCurve: .easeIn)
      CubicKeyframe(-12, duration: 0.12)
      LinearKeyframe(-12, duration: 0.2)
      CubicKeyframe(-60, duration: 0.35)
    }
    KeyframeTrack(\.drop) {
      MoveKeyframe(0)
      LinearKeyframe(0, duration: Slam.hits[2] + 0.3)
      CubicKeyframe(8, duration: 0.37)
    }
    KeyframeTrack(\.opacity) {
      MoveKeyframe(0)
      LinearKeyframe(1, duration: 0.12)
      LinearKeyframe(1, duration: Slam.hits[2] + 0.25)
      LinearKeyframe(0, duration: 0.3)
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
  private static let faceDistance: Float = 5.5
  private static let cameraDistance: Float = 12
  private static let fieldOfView: Float = 38

  let scene = SCNScene()
  private let rig = SCNNode()
  private let swinging = SCNNode()
  private let anchor: SIMD3<Float>

  init() {
    let orientation =
      simd_quatf(angle: 0.6, axis: [0, 0, 1]) * simd_quatf(angle: -0.35, axis: [0, 1, 0])
      * simd_quatf(angle: 0.12, axis: [1, 0, 0])
    let visibleHeight =
      2 * Self.faceDistance * tan(Self.fieldOfView / 2 * .pi / 180)
    let face = SIMD3<Float>(
      0, -Float(Slam.impactHeight - 0.5) * visibleHeight, Self.cameraDistance - Self.faceDistance)
    anchor = face - orientation.act([0, Self.handleLength, Self.headLength / 2])
    rig.simdOrientation = orientation
    rig.simdPosition = anchor
    rig.addChildNode(swinging)
    Self.hammer().forEach(swinging.addChildNode)
    scene.rootNode.addChildNode(rig)

    let camera = SCNNode()
    camera.camera = SCNCamera()
    camera.camera?.fieldOfView = CGFloat(Self.fieldOfView)
    camera.simdPosition = [0, 0, Self.cameraDistance]
    scene.rootNode.addChildNode(camera)

    let key = SCNNode()
    key.light = SCNLight()
    key.light?.type = .directional
    key.light?.intensity = 900
    key.simdLook(at: [0.6, -1, -0.8])
    scene.rootNode.addChildNode(key)
    scene.lightingEnvironment.contents = Self.studio()
    scene.lightingEnvironment.intensity = 1.4
  }

  func pose(_ swing: Swing) {
    swinging.simdEulerAngles.x = Float(swing.angle * .pi / 180)
    rig.simdPosition = anchor - [0, Float(swing.drop), 0]
    rig.opacity = swing.opacity
  }

  private static func hammer() -> [SCNNode] {
    let coated = material(NSColor(white: 0.05, alpha: 1), metalness: 0.6, roughness: 0.42)
    let steel = material(NSColor(white: 0.78, alpha: 1), metalness: 1, roughness: 0.22)
    let rubber = material(NSColor(white: 0.03, alpha: 1), metalness: 0, roughness: 0.75)
    let yellow = material(NSColor(hex: 0xFDBD10), metalness: 0, roughness: 0.45)

    let head = SCNShape(path: octagon(width: 1.05, cut: 0.24), extrusionDepth: CGFloat(headLength))
    head.chamferRadius = 0.08
    head.materials = [steel, steel, coated, steel, steel]
    let collar = SCNCone(topRadius: 0.24, bottomRadius: 0.15, height: 1.1)
    collar.materials = [rubber]
    let shaft = SCNCylinder(radius: 0.16, height: CGFloat(handleLength))
    shaft.materials = [yellow]
    let grip = SCNCylinder(radius: 0.18, height: 1.6)
    grip.materials = [rubber]
    let band = SCNCylinder(radius: 0.185, height: 0.14)
    band.materials = [yellow]
    let knob = SCNSphere(radius: 0.24)
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
    ]
  }

  private static func octagon(width: CGFloat, cut: CGFloat) -> NSBezierPath {
    let half = width / 2
    let path = NSBezierPath()
    let corners = [
      NSPoint(x: -half + cut, y: -half), NSPoint(x: half - cut, y: -half),
      NSPoint(x: half, y: -half + cut), NSPoint(x: half, y: half - cut),
      NSPoint(x: half - cut, y: half), NSPoint(x: -half + cut, y: half),
      NSPoint(x: -half, y: half - cut), NSPoint(x: -half, y: -half + cut),
    ]
    path.move(to: corners[0])
    for corner in corners.dropFirst() { path.line(to: corner) }
    path.close()
    return path
  }

  private static func material(_ color: NSColor, metalness: CGFloat, roughness: CGFloat)
    -> SCNMaterial
  {
    let material = SCNMaterial()
    material.lightingModel = .physicallyBased
    material.diffuse.contents = color
    material.metalness.contents = metalness
    material.roughness.contents = roughness
    return material
  }

  private static func studio() -> NSImage {
    NSImage(size: NSSize(width: 512, height: 256), flipped: false) { rect in
      NSGradient(
        colors: [.init(white: 0.08, alpha: 1), .init(white: 0.45, alpha: 1), .white],
        atLocations: [0, 0.5, 1], colorSpace: .sRGB
      )?.draw(in: rect, angle: 90)
      NSColor.white.setFill()
      NSBezierPath(
        roundedRect: NSRect(x: 60, y: 175, width: 150, height: 50), xRadius: 12, yRadius: 12
      )
      .fill()
      return true
    }
  }
}
