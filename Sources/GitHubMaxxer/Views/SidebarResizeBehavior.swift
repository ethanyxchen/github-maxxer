import AppKit
import SwiftUI

struct SidebarResizeBehavior: NSViewRepresentable {
  func makeNSView(context: Context) -> ConfigurationView { ConfigurationView() }

  func updateNSView(_ nsView: ConfigurationView, context: Context) {
    nsView.configure()
  }

  final class ConfigurationView: NSView {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      configure()
    }

    func configure() {
      let splitView =
        sequence(first: self as NSView, next: { $0.superview })
        .first { $0 is NSSplitView } as? NSSplitView
      guard let controller = splitView?.delegate as? NSSplitViewController,
        let sidebar = controller.splitViewItems.first(where: { $0.behavior == .sidebar }),
        sidebar.collapseBehavior != .useConstraints
      else { return }
      sidebar.collapseBehavior = .useConstraints
    }
  }
}
