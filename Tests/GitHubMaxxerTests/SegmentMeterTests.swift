import SwiftUI
import Testing

@testable import GitHubMaxxer

@MainActor
struct SegmentMeterTests {
  private let shares = [
    MeterShare(id: "personal", title: "Personal", count: 2, target: 1, color: .red),
    MeterShare(id: "org", title: "Org", count: 1, target: 1, color: .blue),
  ]

  @Test func sharedMeterTurnsGreenOnceReached() {
    let meter = SegmentMeter(count: 3, target: 2, isReached: true, shares: shares)
    #expect(meter.color(end: 1) == Palette.reached)
    #expect(meter.color(end: 2) == Palette.reached)
    #expect(meter.color(end: 3) == Palette.over)
  }

  @Test func sharedMeterShowsSharesUntilReached() {
    let meter = SegmentMeter(count: 3, target: 2, isReached: false, shares: shares)
    #expect(meter.color(end: 1) == .red)
    #expect(meter.color(end: 3) == .blue)
  }

  @Test func sharedMeterLeavesUnmergedSegmentsEmpty() {
    let meter = SegmentMeter(count: 3, target: 4, isReached: false, shares: shares)
    #expect(meter.color(end: 4) == Palette.empty)
  }
}
