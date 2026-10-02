import Foundation
import Testing

@testable import GitHubMaxxer

struct ContributionGridTests {
  @Test func hitTestingFollowsCellsWhileResizing() {
    for width in [380.0, 600.0, 900.0] {
      for weeks in [1, 53, 54] {
        let grid = ContributionGridGeometry(width: width, weekCount: weeks)
        for week in 0..<weeks {
          for weekday in 0..<7 {
            let rect = grid.rect(week: week, weekday: weekday)
            let cell = grid.cell(at: CGPoint(x: rect.midX, y: rect.midY))
            #expect(cell?.week == week)
            #expect(cell?.weekday == weekday)
          }
        }
      }
    }
  }

  @Test func labelsGapsAndOutsideTheCalendarHaveNoDay() {
    let grid = ContributionGridGeometry(width: 600, weekCount: 53)
    let first = grid.rect(week: 0, weekday: 0)
    let last = grid.rect(week: 52, weekday: 6)
    for point in [
      CGPoint(x: -1, y: first.midY),
      CGPoint(x: first.minX - 1, y: first.midY),
      CGPoint(x: first.midX, y: first.minY - 1),
      CGPoint(x: first.maxX + 1, y: first.midY),
      CGPoint(x: first.midX, y: first.maxY + 1),
      CGPoint(x: last.maxX + 1, y: last.midY),
      CGPoint(x: last.midX, y: last.maxY + 1),
    ] {
      #expect(grid.cell(at: point) == nil)
    }
  }

  @Test func emptyCalendarHasNoHoverTarget() {
    let grid = ContributionGridGeometry(width: 600, weekCount: 0)
    #expect(grid.cell(at: CGPoint(x: 40, y: 25)) == nil)
  }
}
