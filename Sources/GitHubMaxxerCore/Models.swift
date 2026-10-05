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
  public let ownerKind: RepositoryOwnerKind?

  public init(
    id: String, nameWithOwner: String, isPrivate: Bool,
    ownerKind: RepositoryOwnerKind? = nil
  ) {
    self.id = id
    self.nameWithOwner = nameWithOwner
    self.isPrivate = isPrivate
    self.ownerKind = ownerKind
  }

  public var owner: String { String(nameWithOwner.split(separator: "/").first ?? "") }
  public var name: String { String(nameWithOwner.split(separator: "/").last ?? "") }
}

public struct RepositoryOwnerKind: Codable, Sendable, Hashable {
  public let type: String

  public static let organization = Self(type: "Organization")

  public init(type: String) { self.type = type }

  private enum CodingKeys: String, CodingKey { case type = "__typename" }
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

public struct GitHubSnapshot: Codable, Sendable {
  public let repositories: [Repository]
  public let pullRequests: [MergedPullRequest]
  public let fetchedAt: Date

  public init(
    repositories: [Repository], pullRequests: [MergedPullRequest], fetchedAt: Date
  ) {
    self.repositories = repositories
    self.pullRequests = pullRequests
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
