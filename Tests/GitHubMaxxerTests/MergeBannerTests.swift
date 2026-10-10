import CoreGraphics
import Testing

@testable import GitHubMaxxer

@MainActor
struct MergeBannerTests {
  @Test func keepsPanelOnItsScreenWhenAnotherDisplaySitsAbove() {
    let frame = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let visible = CGRect(x: 0, y: 93, width: 1512, height: 856)

    let placement = MergeBanner.placement(frame: frame, visible: visible)

    #expect(frame.contains(placement.panel))
    #expect(
      placement.panel.contains(
        CGRect(
          x: visible.maxX - 12 - MergeBanner.card.width,
          y: visible.maxY - 12 - MergeBanner.card.height,
          width: MergeBanner.card.width, height: MergeBanner.card.height)))
  }
}
