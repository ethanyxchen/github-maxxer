import Foundation

struct ContributionGridGeometry {
  let width: CGFloat
  let weekCount: Int
  private let origin = CGPoint(x: 34, y: 19)
  private let spacing: CGFloat = 3

  private var cellSize: CGFloat {
    let columns = CGFloat(max(weekCount, 1))
    return min(13, max(5, (width - 36 - (columns - 1) * spacing) / columns))
  }

  func rect(week: Int, weekday: Int) -> CGRect {
    CGRect(
      x: origin.x + CGFloat(week) * (cellSize + spacing),
      y: origin.y + CGFloat(weekday) * (cellSize + spacing),
      width: cellSize, height: cellSize)
  }

  func cell(at point: CGPoint) -> (week: Int, weekday: Int)? {
    guard point.x >= origin.x, point.y >= origin.y else { return nil }
    let week = Int((point.x - origin.x) / (cellSize + spacing))
    let weekday = Int((point.y - origin.y) / (cellSize + spacing))
    guard week < weekCount, weekday < 7,
      rect(week: week, weekday: weekday).contains(point)
    else { return nil }
    return (week, weekday)
  }
}
