import Foundation
import Testing

@testable import GitHubMaxxerCore

struct ActivityTests {
  @Test func dailyGoalHasSafeBoundsForDerivedTargets() {
    #expect(Goals(daily: -1).daily == 1)
    #expect(Goals(daily: Int.max).daily == 10_000)
    #expect(Goals(daily: Int.max).weekly == 50_000)
    #expect(Goals(daily: Int.max).monthly == 200_000)
  }

  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/London")!
    return calendar
  }

  private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }

  private func pull(_ id: String, _ merged: String, repo: String = "acme/app") -> MergedPullRequest
  {
    MergedPullRequest(
      id: id, title: "Improve search", number: 42,
      url: URL(string: "https://github.com/\(repo)/pull/42")!,
      mergedAt: date(merged),
      repository: Repository(id: repo, nameWithOwner: repo, isPrivate: false)
    )
  }

  @Test func localMidnightAndFutureMerges() {
    let now = date("2026-09-30T12:00:00Z")
    let pulls = [
      pull("before", "2026-09-29T22:59:59Z"),
      pull("today", "2026-09-29T23:00:00Z"),
      pull("future", "2026-09-30T13:00:00Z"),
    ]
    #expect(GoalPeriod.day.count(in: pulls, now: now, calendar: calendar) == 1)
  }

  @Test func weeksBeginMondayRegardlessOfLocale() {
    let now = date("2026-09-28T12:00:00Z")
    let pulls = [
      pull("sunday", "2026-09-27T22:59:59Z"),
      pull("monday", "2026-09-27T23:00:00Z"),
    ]
    #expect(GoalPeriod.week.count(in: pulls, now: now, calendar: calendar) == 1)
  }

  @Test func monthUsesLocalCalendarBoundary() {
    let now = date("2026-10-01T12:00:00Z")
    let pulls = [
      pull("september", "2026-09-30T22:59:59Z"),
      pull("october", "2026-09-30T23:00:00Z"),
    ]
    #expect(GoalPeriod.month.count(in: pulls, now: now, calendar: calendar) == 1)
  }

  @Test func deduplicatesOverlappingConnectionsAfterFiltering() {
    let shared = pull("shared", "2026-09-30T10:00:00Z")
    let selected = RepositoryScope(allRepositories: false, owners: ["ACME"])
    let pulls = Activity.mergedPullRequests(from: [
      ScopedActivity(pullRequests: [shared], scope: RepositoryScope(allRepositories: false)),
      ScopedActivity(pullRequests: [shared, shared], scope: selected),
    ])
    #expect(pulls.map(\.id) == ["shared"])
  }

  @Test func selectedOwnersIncludeNewRepositories() {
    let scope = RepositoryScope(
      allRepositories: false, owners: ["acme"], repositories: ["tools"])
    #expect(scope.includes(Repository(id: "new", nameWithOwner: "acme/new", isPrivate: true)))
    #expect(scope.includes(Repository(id: "tools", nameWithOwner: "other/tools", isPrivate: false)))
    #expect(!scope.includes(Repository(id: "no", nameWithOwner: "other/app", isPrivate: false)))
  }

  @Test func allRepositoriesAndEmptySelectionDiffer() {
    let repo = Repository(id: "1", nameWithOwner: "acme/app", isPrivate: true)
    #expect(RepositoryScope().includes(repo))
    #expect(!RepositoryScope(allRepositories: false).includes(repo))
  }

  @Test func repositorySelectionSurvivesRename() {
    let scope = RepositoryScope(allRepositories: false, repositories: ["stable-id"])
    #expect(
      scope.includes(
        Repository(id: "stable-id", nameWithOwner: "new-owner/new-name", isPrivate: true)))
  }

  @Test func historyCoversNinetyLocalCalendarDays() {
    let now = date("2026-09-30T12:00:00Z")
    let interval = Activity.historyInterval(endingAt: now, calendar: calendar)
    #expect(
      calendar.dateComponents([.day], from: interval.start, to: calendar.startOfDay(for: now)).day
        == 89)
    #expect(!interval.contains(now.addingTimeInterval(1)))
  }

  @Test func progressCapsAtOneAndRetainsExcessCount() {
    #expect(GoalProgress(count: 7, target: 5).fraction == 1)
    #expect(GoalProgress(count: 7, target: 5).remaining == 0)
    #expect(GoalProgress(count: 7, target: 5).count == 7)
    #expect(GoalProgress(count: 0, target: 0).fraction == 0)
  }
}
