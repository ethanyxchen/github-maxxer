import Foundation

public struct GitHubProfile: Codable, Sendable, Hashable {
  public let id: String
  public let login: String
  public let name: String?
  public let avatarUrl: URL

  public init(id: String, login: String, name: String?, avatarUrl: URL) {
    self.id = id
    self.login = login
    self.name = name
    self.avatarUrl = avatarUrl
  }

  public var displayName: String { name.flatMap { $0.isEmpty ? nil : $0 } ?? login }
}

public struct Repository: Codable, Sendable, Hashable, Identifiable {
  public let id: String
  public let nameWithOwner: String
  public let isPrivate: Bool

  public init(id: String, nameWithOwner: String, isPrivate: Bool) {
    self.id = id
    self.nameWithOwner = nameWithOwner
    self.isPrivate = isPrivate
  }

  public var owner: String { String(nameWithOwner.split(separator: "/").first ?? "") }
  public var name: String { String(nameWithOwner.split(separator: "/").last ?? "") }
}

public struct MergedPullRequest: Codable, Sendable, Hashable, Identifiable {
  public let id: String
  public let title: String
  public let number: Int
  public let url: URL
  public let mergedAt: Date
  public let repository: Repository

  public init(
    id: String, title: String, number: Int, url: URL, mergedAt: Date, repository: Repository
  ) {
    self.id = id
    self.title = title
    self.number = number
    self.url = url
    self.mergedAt = mergedAt
    self.repository = repository
  }
}

public struct ContributionCalendar: Codable, Sendable {
  public let totalContributions: Int
  public let weeks: [ContributionWeek]

  public init(totalContributions: Int, weeks: [ContributionWeek]) {
    self.totalContributions = totalContributions
    self.weeks = weeks
  }
}

public struct ContributionWeek: Codable, Sendable {
  public let firstDay: String
  public let contributionDays: [ContributionDay]

  public init(firstDay: String, contributionDays: [ContributionDay]) {
    self.firstDay = firstDay
    self.contributionDays = contributionDays
  }
}

public struct ContributionDay: Codable, Sendable, Identifiable {
  public let date: String
  public let weekday: Int
  public let contributionCount: Int
  public let contributionLevel: ContributionLevel
  public var id: String { date }

  public init(
    date: String, weekday: Int, contributionCount: Int, contributionLevel: ContributionLevel
  ) {
    self.date = date
    self.weekday = weekday
    self.contributionCount = contributionCount
    self.contributionLevel = contributionLevel
  }
}

public enum ContributionLevel: String, Codable, Sendable, CaseIterable {
  case none = "NONE"
  case first = "FIRST_QUARTILE"
  case second = "SECOND_QUARTILE"
  case third = "THIRD_QUARTILE"
  case fourth = "FOURTH_QUARTILE"
}

public struct GitHubSnapshot: Codable, Sendable {
  public let repositories: [Repository]
  public let pullRequests: [MergedPullRequest]
  public let contributions: ContributionCalendar
  public let fetchedAt: Date

  public init(
    repositories: [Repository], pullRequests: [MergedPullRequest],
    contributions: ContributionCalendar, fetchedAt: Date
  ) {
    self.repositories = repositories
    self.pullRequests = pullRequests
    self.contributions = contributions
    self.fetchedAt = fetchedAt
  }
}

public struct RepositoryScope: Codable, Sendable, Equatable {
  public var allRepositories: Bool
  public var owners: Set<String>
  public var repositories: Set<String>

  public init(
    allRepositories: Bool = true, owners: Set<String> = [], repositories: Set<String> = []
  ) {
    self.allRepositories = allRepositories
    self.owners = owners
    self.repositories = repositories
  }

  public func includes(_ repository: Repository) -> Bool {
    allRepositories
      || includesOwner(repository.owner)
      || repositories.contains(repository.id)
  }

  public func includesOwner(_ owner: String) -> Bool {
    owners.contains { $0.caseInsensitiveCompare(owner) == .orderedSame }
  }
}
