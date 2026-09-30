import Foundation

public enum GoalPeriod: String, CaseIterable, Codable, Sendable, Identifiable {
  case day, week, month

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .day: "Today"
    case .week: "This week"
    case .month: "This month"
    }
  }

  public var targetLabel: String {
    switch self {
    case .day: "Daily target"
    case .week: "Weekly target"
    case .month: "Monthly target"
    }
  }

  public func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
    var calendar = calendar
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    let component: Calendar.Component =
      switch self {
      case .day: .day
      case .week: .weekOfYear
      case .month: .month
      }
    return calendar.dateInterval(of: component, for: date)!
  }

  public func count(in pullRequests: [MergedPullRequest], now: Date, calendar: Calendar = .current)
    -> Int
  {
    let interval = interval(containing: now, calendar: calendar)
    return pullRequests.filter {
      $0.mergedAt >= interval.start && $0.mergedAt < interval.end && $0.mergedAt <= now
    }.count
  }
}

public struct Goals: Codable, Sendable, Equatable {
  public var daily: Int
  public var weekly: Int
  public var monthly: Int

  public init(daily: Int = 1, weekly: Int = 5, monthly: Int = 20) {
    self.daily = daily
    self.weekly = weekly
    self.monthly = monthly
  }

  public subscript(period: GoalPeriod) -> Int {
    get {
      switch period {
      case .day: daily
      case .week: weekly
      case .month: monthly
      }
    }
    set {
      let value = max(1, newValue)
      switch period {
      case .day: daily = value
      case .week: weekly = value
      case .month: monthly = value
      }
    }
  }
}

public struct GoalProgress: Sendable {
  public let count: Int
  public let target: Int

  public init(count: Int, target: Int) {
    self.count = count
    self.target = target
  }

  public var fraction: Double { target > 0 ? min(Double(count) / Double(target), 1) : 0 }
  public var remaining: Int { max(target - count, 0) }
  public var isComplete: Bool { target > 0 && count >= target }
}

public struct ScopedActivity: Sendable {
  public let pullRequests: [MergedPullRequest]
  public let scope: RepositoryScope

  public init(pullRequests: [MergedPullRequest], scope: RepositoryScope) {
    self.pullRequests = pullRequests
    self.scope = scope
  }
}

public enum Activity {
  public static func historyInterval(endingAt now: Date, calendar: Calendar = .current)
    -> DateInterval
  {
    let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -89, to: now)!)
    return DateInterval(start: start, end: now)
  }

  public static func mergedPullRequests(from sources: [ScopedActivity]) -> [MergedPullRequest] {
    var seen = Set<String>()
    var result: [MergedPullRequest] = []
    for source in sources {
      for pull in source.pullRequests where source.scope.includes(pull.repository) {
        if seen.insert(pull.id).inserted { result.append(pull) }
      }
    }
    return result.sorted {
      $0.mergedAt == $1.mergedAt ? $0.id < $1.id : $0.mergedAt > $1.mergedAt
    }
  }
}
