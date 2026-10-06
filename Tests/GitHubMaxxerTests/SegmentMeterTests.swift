import SwiftUI
import Testing

@testable import GitHubMaxxer

@MainActor
struct SegmentMeterTests {
  private let shares = [
    MeterShare(id: "personal", title: "Personal", count: 2, target: 1, color: .red),
    MeterShare(id: "org", title: "Org", count: 1, target: 1, color: .blue),
  ]

  @Test func sharedMeterTurnsGreenOnceTargetIsReached() {
    let meter = SegmentMeter(count: 3, target: 2, shares: shares)
    #expect(meter.color(end: 1) == Palette.reached)
    #expect(meter.color(end: 2) == Palette.reached)
    #expect(meter.color(end: 3) == Palette.over)
  }

  @Test func sharedMeterKeepsSharesWhileAnyShareIsBelowItsTarget() {
    let behind = [
      MeterShare(id: "personal", title: "Personal", count: 3, target: 1, color: .red),
      MeterShare(id: "org", title: "Org", count: 0, target: 1, color: .blue),
    ]
    let meter = SegmentMeter(count: 3, target: 2, shares: behind)
    #expect(meter.color(end: 1) == .red)
    #expect(meter.color(end: 3) == .red)
  }

  @Test func sharedMeterShowsSharesBeforeTargetIsReached() {
    let meter = SegmentMeter(count: 3, target: 4, shares: shares)
    #expect(meter.color(end: 1) == .red)
    #expect(meter.color(end: 3) == .blue)
    #expect(meter.color(end: 4) == Palette.empty)
  }
}
