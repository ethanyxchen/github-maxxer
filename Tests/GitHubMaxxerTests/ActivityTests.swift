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

  private func pull(
    _ id: String, _ merged: String, repo: String = "acme/app",
    ownerKind: RepositoryOwnerKind? = nil
  ) -> MergedPullRequest {
    MergedPullRequest(
      id: id, title: "Improve search", number: 42,
      url: URL(string: "https://github.com/\(repo)/pull/42")!,
      mergedAt: date(merged),
      repository: Repository(id: repo, nameWithOwner: repo, isPrivate: false, ownerKind: ownerKind)
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

  @Test func calendarWeekListExcludesPreviousWeekAndFutureMerges() {
    let now = date("2026-10-01T12:00:00Z")
    let pulls = [
      pull("now", "2026-10-01T12:00:00Z"),
      pull("monday", "2026-09-27T23:00:00Z"),
      pull("sunday", "2026-09-27T22:59:59Z"),
      pull("friday", "2026-09-25T12:00:00Z"),
      pull("future", "2026-10-01T13:00:00Z"),
    ]
    let selected = GoalPeriod.week.pullRequests(in: pulls, now: now, calendar: calendar)
    #expect(selected.map(\.id) == ["now", "monday"])
    #expect(selected.count == GoalPeriod.week.count(in: pulls, now: now, calendar: calendar))
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

  @Test func activityFiltersSeparatePersonalAndOrganizationRepositories() {
    let personal = pull("personal", "2026-09-30T10:00:00Z", repo: "alex/tools")
    let work = pull("work", "2026-09-30T11:00:00Z", repo: "acme/app", ownerKind: .organization)
    let collaborator = pull("collaborator", "2026-09-30T12:00:00Z", repo: "someone/project")
    let pulls = [personal, work, collaborator]
    let personalLogins: Set<String> = ["Alex"]
    #expect(
      ActivityFilter.personal.pullRequests(in: pulls, personalLogins: personalLogins).map(\.id) == [
        "personal"
      ])
    #expect(
      ActivityFilter.organization("ACME").pullRequests(in: pulls, personalLogins: personalLogins)
        .map(\.id) == ["work"])
    #expect(ActivityFilter.all.pullRequests(in: pulls, personalLogins: personalLogins).count == 3)
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

  @Test func paceCountsElapsedWorkdays() {
    let friday = date("2026-10-02T12:00:00Z")
    let wednesday = date("2026-09-30T12:00:00Z")
    #expect(GoalPeriod.month.pace(target: 60, now: friday, calendar: calendar) == 5)
    #expect(GoalPeriod.week.pace(target: 15, now: friday, calendar: calendar) == 15)
    #expect(GoalPeriod.week.pace(target: 15, now: wednesday, calendar: calendar) == 9)
    #expect(GoalPeriod.day.pace(target: 3, now: friday, calendar: calendar) == 3)
  }

  @Test func dailyCountsCoverHistoryByLocalDay() {
    let now = date("2026-10-02T12:00:00Z")
    let pulls = [
      pull("today", "2026-10-02T09:00:00Z"),
      pull("local-today", "2026-10-01T23:30:00Z"),
      pull("yesterday", "2026-10-01T22:59:59Z"),
    ]
    let days = Activity.dailyCounts(pulls, endingAt: now, calendar: calendar)
    #expect(days.count == 90)
    #expect(days.last?.count == 2)
    #expect(days.dropLast().last?.count == 1)
    #expect(days.first?.day == Activity.historyInterval(endingAt: now, calendar: calendar).start)
  }

  @Test func weeksStartOnMondayAndPadPartialWeeks() {
    let now = date("2026-10-02T12:00:00Z")
    let days = Activity.dailyCounts([], endingAt: now, calendar: calendar)
    let weeks = Activity.weeks(days, calendar: calendar)
    #expect(weeks.allSatisfy { $0.count == 7 })
    #expect(weeks.flatMap { $0 }.compactMap { $0 }.count == 90)
    let firstMonday = weeks[1][0].map { calendar.component(.weekday, from: $0.day) }
    #expect(firstMonday == 2)
    #expect(weeks.last?[4]?.day == calendar.startOfDay(for: now))
  }

  @Test func progressCapsAtOneAndRetainsExcessCount() {
    #expect(GoalProgress(count: 7, target: 5).fraction == 1)
    #expect(GoalProgress(count: 7, target: 5).remaining == 0)
    #expect(GoalProgress(count: 7, target: 5).count == 7)
    #expect(GoalProgress(count: 0, target: 0).fraction == 0)
  }
}
