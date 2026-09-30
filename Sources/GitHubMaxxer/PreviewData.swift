import Foundation
import GitHubMaxxerCore

enum PreviewData {
  static func connections(now: Date) -> [AccountConnection] {
    let profile = GitHubProfile(
      id: "preview-user", login: "alexmorgan", name: "Alex Morgan",
      avatarUrl: URL(string: "https://github.com/identicons/alexmorgan.png")!
    )
    let repositories = [
      Repository(id: "1", nameWithOwner: "northstar/desktop", isPrivate: true),
      Repository(id: "2", nameWithOwner: "northstar/platform", isPrivate: true),
      Repository(id: "3", nameWithOwner: "alexmorgan/dotfiles", isPrivate: false),
      Repository(id: "4", nameWithOwner: "alexmorgan/swift-tools", isPrivate: false),
    ]
    let titles = [
      "Keep search selection when results update", "Add keyboard navigation to the sidebar",
      "Simplify token refresh handling", "Improve empty states in the activity view",
      "Fix window restoration on launch", "Remove unused build steps",
      "Add tests for calendar boundaries", "Update Swift toolchain",
    ]
    let pulls = (0..<32).map { index in
      MergedPullRequest(
        id: "preview-pr-\(index)", title: titles[index % titles.count], number: 248 - index,
        url: URL(
          string: "https://github.com/\(repositories[index % 4].nameWithOwner)/pull/\(248 - index)")!,
        mergedAt: now.addingTimeInterval(-Double(index * index + index) * 4_000),
        repository: repositories[index % 4]
      )
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let today = calendar.startOfDay(for: now)
    let yearStart = calendar.date(byAdding: .year, value: -1, to: today)!
    let start = calendar.date(
      byAdding: .day, value: -(calendar.component(.weekday, from: yearStart) - 1), to: yearStart)!
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    var weeks: [ContributionWeek] = []
    var total = 0
    for week in 0..<54 {
      let first = calendar.date(byAdding: .day, value: week * 7, to: start)!
      guard first <= today else { break }
      var days: [ContributionDay] = []
      for weekday in 0..<7 {
        let day = calendar.date(byAdding: .day, value: week * 7 + weekday, to: start)!
        guard day >= yearStart, day <= today else { continue }
        let value = (week * 17 + weekday * 7 + week / 3) % 13
        let count = weekday == 0 || weekday == 6 ? value % 3 : value
        let level: ContributionLevel =
          count == 0
          ? .none : count < 3 ? .first : count < 6 ? .second : count < 9 ? .third : .fourth
        total += count
        days.append(
          ContributionDay(
            date: formatter.string(from: day), weekday: weekday, contributionCount: count,
            contributionLevel: level))
      }
      weeks.append(
        ContributionWeek(firstDay: formatter.string(from: first), contributionDays: days))
    }
    let snapshot = GitHubSnapshot(
      repositories: repositories, pullRequests: pulls,
      contributions: ContributionCalendar(totalContributions: total, weeks: weeks), fetchedAt: now)
    return [
      AccountConnection(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, label: "Work",
        profile: profile, scope: RepositoryScope(allRepositories: false, owners: ["northstar"]),
        snapshot: snapshot
      ),
      AccountConnection(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, label: "Personal",
        profile: profile, scope: RepositoryScope(allRepositories: false, owners: ["alexmorgan"]),
        snapshot: snapshot
      ),
    ]
  }
}
