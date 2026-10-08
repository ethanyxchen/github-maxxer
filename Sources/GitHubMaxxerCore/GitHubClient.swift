import Foundation

public struct GitHubClient: Sendable {
  private let token: String
  private let session: URLSession

  public init(token: String, session: URLSession = .shared) {
    self.token = token
    self.session = session
  }

  public func profile() async throws -> GitHubProfile {
    let response: ProfileResponse = try await query(
      "query { viewer { id login name avatarUrl } }", variables: EmptyVariables()
    )
    return response.viewer
  }

  public func snapshot(login: String, now: Date = .now) async throws -> GitHubSnapshot {
    async let repositories = repositories()
    let start = Activity.historyInterval(endingAt: now).start
    async let pulls = mergedPullRequests(login: login, from: start, through: now)
    let (accessible, merged) = try await (repositories, pulls)
    var seen = Set<String>()
    let visibleRepositories = (accessible + merged.map(\.repository)).filter {
      seen.insert($0.id).inserted
    }
    .sorted { $0.nameWithOwner.localizedStandardCompare($1.nameWithOwner) == .orderedAscending }
    return GitHubSnapshot(
      repositories: visibleRepositories, pullRequests: merged, fetchedAt: now)
  }

  private func repositories() async throws -> [Repository] {
    var cursor: String?
    var result: [Repository] = []
    repeat {
      let response: RepositoriesResponse = try await query(
        """
        query($after: String) {
          viewer {
            repositories(first: 100, after: $after, ownerAffiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER]) {
              nodes { id nameWithOwner isPrivate ownerKind: owner { __typename } }
              pageInfo { hasNextPage endCursor }
            }
          }
        }
        """,
        variables: PageVariables(after: cursor)
      )
      result.append(contentsOf: response.viewer.repositories.nodes)
      cursor = try response.viewer.repositories.pageInfo.nextCursor(previous: cursor)
    } while cursor != nil
    return result
  }

  private func mergedPullRequests(login: String, from start: Date, through end: Date) async throws
    -> [MergedPullRequest]
  {
    let formatter = ISO8601DateFormatter()
    let search =
      "is:pr is:merged author:\(login) merged:\(formatter.string(from: start))..\(formatter.string(from: end)) sort:updated-desc"
    var cursor: String?
    var result: [MergedPullRequest] = []
    repeat {
      let response: SearchResponse = try await query(
        """
        query($query: String!, $after: String) {
          search(query: $query, type: ISSUE, first: 100, after: $after) {
            issueCount
            nodes {
              ... on PullRequest {
                id title number url mergedAt
                repository { id nameWithOwner isPrivate ownerKind: owner { __typename } }
              }
            }
            pageInfo { hasNextPage endCursor }
          }
        }
        """,
        variables: SearchVariables(query: search, after: cursor)
      )
      if response.search.issueCount > 1_000 {
        let first = floor(start.timeIntervalSince1970)
        let last = floor(end.timeIntervalSince1970)
        guard last > first else { throw GitHubError.searchLimit }
        let middle = floor((first + last) / 2)
        async let earlier = mergedPullRequests(
          login: login, from: Date(timeIntervalSince1970: first),
          through: Date(timeIntervalSince1970: middle))
        async let later = mergedPullRequests(
          login: login, from: Date(timeIntervalSince1970: middle + 1),
          through: Date(timeIntervalSince1970: last))
        return try await earlier + later
      }
      result.append(contentsOf: response.search.nodes)
      cursor = try response.search.pageInfo.nextCursor(previous: cursor)
    } while cursor != nil
    return result
  }

  private func query<Response: Decodable & Sendable, Variables: Encodable & Sendable>(
    _ query: String, variables: Variables
  ) async throws -> Response {
    var request = URLRequest(url: URL(string: "https://api.github.com/graphql")!)
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("Hammertime", forHTTPHeaderField: "User-Agent")
    request.httpBody = try JSONEncoder().encode(GraphQLRequest(query: query, variables: variables))
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw GitHubError.invalidResponse }
    switch response.statusCode {
    case 200: break
    case 401: throw GitHubError.unauthorized
    case 403, 429:
      if response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0"
        || response.statusCode == 429
      {
        throw GitHubError.rateLimited
      }
      throw GitHubError.forbidden
    default: throw GitHubError.http(response.statusCode)
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let failures = try decoder.decode(GraphQLFailures.self, from: data)
    if let error = failures.errors?.first {
      throw GitHubError.graphQL(error.message)
    }
    let envelope = try decoder.decode(GraphQLResponse<Response>.self, from: data)
    guard let result = envelope.data else { throw GitHubError.invalidResponse }
    return result
  }
}

public enum GitHubError: LocalizedError, Sendable {
  case unauthorized, forbidden, rateLimited, invalidResponse, searchLimit
  case http(Int)
  case graphQL(String)

  public var errorDescription: String? {
    switch self {
    case .unauthorized: "GitHub rejected this connection. Sign in again."
    case .forbidden:
      "GitHub denied access. Check this connection's repository access and your organization's app approval or SSO authorization."
    case .rateLimited:
      "GitHub's request limit was reached. Your last activity is still available; try again later."
    case .invalidResponse: "GitHub returned an incomplete response. Try refreshing again."
    case .searchLimit:
      "Too many PRs were merged in a single search window. Activity could not be loaded completely."
    case .http(let status): "GitHub returned HTTP \(status). Try again later."
    case .graphQL(let message): "GitHub: \(message)"
    }
  }
}

private struct EmptyVariables: Encodable, Sendable {}
private struct PageVariables: Encodable, Sendable { let after: String? }
private struct SearchVariables: Encodable, Sendable {
  let query: String
  let after: String?
}
private struct GraphQLRequest<Variables: Encodable>: Encodable {
  let query: String
  let variables: Variables
}
private struct GraphQLResponse<Response: Decodable>: Decodable {
  let data: Response?
}
private struct GraphQLFailures: Decodable {
  let errors: [Failure]?
  struct Failure: Decodable { let message: String }
}
private struct PageInfo: Decodable, Sendable {
  let hasNextPage: Bool
  let endCursor: String?

  func nextCursor(previous: String?) throws -> String? {
    guard hasNextPage else { return nil }
    guard let endCursor, endCursor != previous else { throw GitHubError.invalidResponse }
    return endCursor
  }
}
private struct Page<Node: Decodable & Sendable>: Decodable, Sendable {
  let nodes: [Node]
  let pageInfo: PageInfo
}
private struct ProfileResponse: Decodable, Sendable { let viewer: GitHubProfile }
private struct RepositoriesResponse: Decodable, Sendable {
  let viewer: Viewer
  struct Viewer: Decodable, Sendable { let repositories: Page<Repository> }
}
private struct SearchResponse: Decodable, Sendable {
  let search: Search
  struct Search: Decodable, Sendable {
    let issueCount: Int
    let nodes: [MergedPullRequest]
    let pageInfo: PageInfo
  }
}
