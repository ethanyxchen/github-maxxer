import AppKit
import GitHubMaxxerCore
import SwiftUI
import os

@MainActor
final class MergeBanner {
  fileprivate static let card = CGSize(width: 380, height: 68)
  fileprivate static let stage = CGSize(width: 640, height: 420)
  fileprivate static let overscan = 2.0
  private static let canvas = CGSize(
    width: stage.width * overscan, height: stage.height * overscan)
  fileprivate static let margin = 12.0
  private static let lifetime = 8.0
  fileprivate static let exit = 0.35
  private let model: AppModel
  private let panel = NSPanel(
    contentRect: CGRect(origin: .zero, size: canvas),
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered, defer: true)
  private var shown: Date?

  init(model: AppModel) {
    self.model = model
    panel.level = NSWindow.Level(NSWindow.Level.screenSaver.rawValue + 1)
    panel.collectionBehavior = [
      .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
    ]
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.canHide = false
    panel.contentView = NSHostingView(
      rootView: BannerStage(dismiss: model.releaseBanner).environment(model)
        .frame(width: Self.canvas.width, height: Self.canvas.height))
    observe()
  }

  private func observe() {
    let banner = withObservationTracking {
      model.banner
    } onChange: { [weak self] in
      Task { @MainActor in self?.observe() }
    }
    present(banner)
  }

  private func present(_ banner: Landing?) {
    guard let banner else {
      shown = nil
      Task {
        try? await Task.sleep(for: .seconds(Self.exit))
        if shown == nil, panel.isVisible {
          panel.orderOut(nil)
          Logger.merges.log("Hid banner")
        }
      }
      return
    }
    let pointer = NSEvent.mouseLocation
    let pointed = NSScreen.screens.first { $0.frame.contains(pointer) }
    guard banner.date != shown else { return }
    guard let screen = pointed ?? NSScreen.main else {
      Logger.merges.error("No screen for the banner")
      return
    }
    shown = banner.date
    let visible = screen.visibleFrame
    let center = CGPoint(
      x: visible.maxX - Self.margin - Self.card.width / 2,
      y: visible.maxY - Self.margin - Self.card.height / 2)
    panel.setFrameOrigin(
      CGPoint(
        x: center.x - Self.canvas.width / 2,
        y: center.y - Self.canvas.height / 2 + Self.stage.height * (Slam.impactHeight - 0.5)))
    panel.orderFrontRegardless()
    Logger.merges.log(
      "Showed banner on \(screen.localizedName, privacy: .public) at \(String(describing: self.panel.frame), privacy: .public)"
    )
    Task {
      try? await Task.sleep(for: .seconds(Slam.impact))
      Logger.merges.log(
        "Banner on screen at impact: \(self.panel.occlusionState.contains(.visible))")
      try? await Task.sleep(for: .seconds(Self.lifetime - Slam.impact))
      if shown == banner.date { model.releaseBanner() }
    }
  }
}

private struct BannerStage: View {
  let dismiss: () -> Void
  @Environment(AppModel.self) private var model
  @Environment(\.openWindow) private var openWindow
  @State private var isHovering = false

  private let offstage = AnyTransition.offset(x: MergeBanner.card.width + MergeBanner.margin)

  var body: some View {
    ZStack {
      if let banner = model.banner {
        BannerCard(pulls: model.announced, landing: banner)
          .onTapGesture {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
          }
          .overlay(alignment: .topLeading) {
            Button("Close", systemImage: "xmark", action: dismiss)
              .labelStyle(.iconOnly)
              .buttonStyle(.plain)
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(Palette.secondary)
              .frame(width: 20, height: 20)
              .background(Palette.panel, in: .circle)
              .overlay { Circle().strokeBorder(Palette.rule) }
              .offset(x: -7, y: -7)
              .opacity(isHovering ? 1 : 0)
          }
          .onHover { isHovering = $0 }
          .position(
            x: MergeBanner.stage.width / 2, y: MergeBanner.stage.height * Slam.impactHeight
          )
          .transition(
            .asymmetric(
              insertion: offstage, removal: offstage.combined(with: .opacity)))
        HammerSwing(landing: banner, overscan: MergeBanner.overscan)
          .transition(.identity)
      }
    }
    .frame(width: MergeBanner.stage.width, height: MergeBanner.stage.height)
    .animation(
      model.banner == nil
        ? .easeIn(duration: MergeBanner.exit) : .easeOut(duration: Slam.settle),
      value: model.banner == nil)
  }
}

private struct BannerCard: View {
  let pulls: [MergedPullRequest]
  let landing: Landing

  var body: some View {
    HStack(spacing: 12) {
      Image(nsImage: NSApplication.shared.applicationIconImage).resizable()
        .frame(width: 34, height: 34)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
        Text(detail).font(.system(size: 11, design: .monospaced))
          .foregroundStyle(Palette.secondary)
      }
      .lineLimit(1)
      Spacer(minLength: 8)
      MergedStamp(landing: landing).frame(height: 24)
    }
    .padding(.horizontal, 14)
    .frame(width: MergeBanner.card.width, height: MergeBanner.card.height)
    .background(Palette.panel, in: .rect(cornerRadius: 18))
    .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.rule) }
    .overlay { HammerShatter(landing: landing).clipShape(.rect(cornerRadius: 18)) }
    .contentShape(.rect(cornerRadius: 18))
    .accessibilityElement(children: .combine)
  }

  private var title: String {
    pulls.count == 1 ? pulls[0].title : "\(pulls.count) PRs merged"
  }

  private var detail: String {
    guard pulls.count == 1 else {
      return Set(pulls.map(\.repository.name)).sorted().joined(separator: ", ")
    }
    return "#\(String(pulls[0].number)) · \(pulls[0].repository.name)"
  }
}
