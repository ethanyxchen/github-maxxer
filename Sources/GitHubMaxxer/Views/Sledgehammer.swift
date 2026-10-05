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
  private static let handleLength: Float = 8.79
  private static let strikerDepth: Float = 0.96
  private static let glassDistance: Float = 8
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
    rig.simdPosition = face - orientation.act([0, Self.handleLength, -Self.strikerDepth])
    rig.addChildNode(swinging)
    swinging.addChildNode(Self.scanned())
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
    scene.lightingEnvironment.contents = Bundle.module.url(
      forResource: "Studio", withExtension: "hdr")
    scene.lightingEnvironment.intensity = 1.2
  }

  func pose(_ swing: Swing) {
    swinging.simdEulerAngles.x = Float(swing.angle * .pi / 180)
  }

  private static func scanned() -> SCNNode {
    let model = SCNNode()
    if let url = Bundle.module.url(forResource: "Sledgehammer", withExtension: "obj"),
      let scene = try? SCNScene(url: url)
    {
      for child in scene.rootNode.childNodes { model.addChildNode(child) }
    }
    let material = SCNMaterial()
    material.lightingModel = .physicallyBased
    let texture = { (name: String) in
      Bundle.module.url(forResource: "Sledgehammer\(name)", withExtension: nil)
    }
    material.diffuse.contents = texture("Color.jpg")
    material.normal.contents = texture("Normal.png")
    material.roughness.contents = texture("Roughness.jpg")
    material.metalness.contents = texture("Metalness.jpg")
    model.enumerateHierarchy { node, _ in node.geometry?.materials = [material] }
    model.simdPosition = [0, 0.27, 5.19]
    let container = SCNNode()
    container.simdOrientation =
      simd_quatf(angle: .pi, axis: [0, 1, 0])
      * simd_quatf(angle: .pi, axis: simd_normalize([0, 1, 1]))
    container.addChildNode(model)
    return container
  }
}
