import Foundation
import Testing

@testable import GitHubMaxxerCore

@Suite(.serialized)
struct GitHubClientTests {
  private func client(_ handler: @escaping @Sendable (URLRequest) throws -> StubResponse)
    -> GitHubClient
  {
    StubProtocol.handler.set(handler)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubProtocol.self]
    return GitHubClient(token: "test-token", session: URLSession(configuration: configuration))
  }

  @Test func verifiesIdentityAndAuthorizationHeader() async throws {
    let client = client { request in
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
      return StubResponse(
        body:
          "{\"data\":{\"viewer\":{\"id\":\"u1\",\"login\":\"alex\",\"name\":null,\"avatarUrl\":\"https://github.com/alex.png\"}}}"
      )
    }
    let profile = try await client.profile()
    #expect(profile.login == "alex")
    #expect(profile.displayName == "alex")
  }

  @Test func rejectsUnauthorizedCredential() async {
    let client = client { _ in StubResponse(status: 401, body: "{}") }
    await #expect(throws: GitHubError.self) { try await client.profile() }
  }

  @Test func rejectsPartialGraphQLData() async {
    let client = client { _ in
      StubResponse(
        body:
          "{\"data\":{\"viewer\":{\"id\":\"u1\",\"login\":\"alex\",\"name\":null,\"avatarUrl\":\"https://github.com/alex.png\"}},\"errors\":[{\"message\":\"Access denied\"}]}"
      )
    }
    await #expect(throws: GitHubError.self) { try await client.profile() }
  }

  @Test func paginatesRepositoriesAndMergedPullRequests() async throws {
    let client = client { request in
      let body = try requestBody(request)
      let query = body["query"] as! String
      let after = (body["variables"] as? [String: Any])?["after"] as? String
      if query.contains("contributionsCollection") { return calendarResponse }
      if query.contains("repositories(first") {
        let id = after == nil ? "r1" : "r2"
        let next = after == nil ? "\"repo-page-2\"" : "null"
        return StubResponse(
          body:
            "{\"data\":{\"viewer\":{\"repositories\":{\"nodes\":[\(repositoryJSON(id))],\"pageInfo\":{\"hasNextPage\":\(after == nil),\"endCursor\":\(next)}}}}}"
        )
      }
      let id = after == nil ? "p1" : "p2"
      return searchResponse(
        count: 2, nodes: [pullJSON(id)], next: after == nil ? "pull-page-2" : nil)
    }
    let snapshot = try await client.snapshot(login: "alex", now: fixedNow)
    #expect(snapshot.repositories.map(\.id) == ["r1", "r2"])
    #expect(snapshot.pullRequests.map(\.id) == ["p1", "p2"])
    #expect(snapshot.contributions.totalContributions == 12)
  }

  @Test func partitionsSearchAboveGitHubResultLimit() async throws {
    let searches = LockedValues<String>()
    let client = client { request in
      let body = try requestBody(request)
      let query = body["query"] as! String
      if query.contains("contributionsCollection") { return calendarResponse }
      if query.contains("repositories(first") { return emptyRepositories }
      let search = (body["variables"] as! [String: Any])["query"] as! String
      let index = searches.append(search)
      if index == 0 { return searchResponse(count: 1_001, nodes: []) }
      return searchResponse(count: 1, nodes: [pullJSON("p\(index)")])
    }
    let snapshot = try await client.snapshot(login: "alex", now: fixedNow)
    #expect(snapshot.pullRequests.count == 2)
    #expect(snapshot.repositories.count == 1)
    let queries = searches.values
    #expect(queries.count == 3)
    let leftEnd = queries[1].split(separator: " ").first { $0.hasPrefix("merged:<") }!.dropFirst(8)
    let rightStart = queries[2].split(separator: " ").first { $0.hasPrefix("merged:>=") }!
      .dropFirst(9)
    #expect(leftEnd == rightStart)
  }

  @Test func rejectsMissingPaginationCursor() async {
    let client = client { request in
      let query = try requestBody(request)["query"] as! String
      if query.contains("contributionsCollection") { return calendarResponse }
      if query.contains("repositories(first") {
        return StubResponse(
          body:
            "{\"data\":{\"viewer\":{\"repositories\":{\"nodes\":[],\"pageInfo\":{\"hasNextPage\":true,\"endCursor\":null}}}}}"
        )
      }
      return searchResponse(count: 0, nodes: [])
    }
    await #expect(throws: GitHubError.self) {
      try await client.snapshot(login: "alex", now: fixedNow)
    }
  }
}

private let fixedNow = ISO8601DateFormatter().date(from: "2026-09-30T12:00:00Z")!
private let calendarResponse = StubResponse(
  body:
    "{\"data\":{\"viewer\":{\"contributionsCollection\":{\"contributionCalendar\":{\"totalContributions\":12,\"weeks\":[]}}}}}"
)
private let emptyRepositories = StubResponse(
  body:
    "{\"data\":{\"viewer\":{\"repositories\":{\"nodes\":[],\"pageInfo\":{\"hasNextPage\":false,\"endCursor\":null}}}}}"
)

private func repositoryJSON(_ id: String) -> String {
  "{\"id\":\"\(id)\",\"nameWithOwner\":\"acme/\(id)\",\"isPrivate\":false}"
}

private func pullJSON(_ id: String) -> String {
  "{\"id\":\"\(id)\",\"title\":\"Improve search\",\"number\":42,\"url\":\"https://github.com/acme/r1/pull/42\",\"mergedAt\":\"2026-09-30T10:00:00Z\",\"repository\":\(repositoryJSON("r1"))}"
}

private func searchResponse(count: Int, nodes: [String], next: String? = nil) -> StubResponse {
  let cursor = next.map { "\"\($0)\"" } ?? "null"
  return StubResponse(
    body:
      "{\"data\":{\"search\":{\"issueCount\":\(count),\"nodes\":[\(nodes.joined(separator: ","))],\"pageInfo\":{\"hasNextPage\":\(next != nil),\"endCursor\":\(cursor)}}}}"
  )
}

private func requestBody(_ request: URLRequest) throws -> [String: Any] {
  let data: Data
  if let body = request.httpBody {
    data = body
  } else if let stream = request.httpBodyStream {
    stream.open()
    defer { stream.close() }
    var collected = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
      let read = stream.read(&buffer, maxLength: buffer.count)
      if read <= 0 { break }
      collected.append(buffer, count: read)
    }
    data = collected
  } else {
    data = Data()
  }
  return try JSONSerialization.jsonObject(with: data) as! [String: Any]
}

private struct StubResponse: Sendable {
  var status = 200
  var body: String
}

private final class LockedValues<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: [Value] = []
  var values: [Value] { lock.withLock { stored } }
  func append(_ value: Value) -> Int {
    lock.withLock {
      let index = stored.count
      stored.append(value)
      return index
    }
  }
}

private final class StubHandler: @unchecked Sendable {
  private let lock = NSLock()
  private var handler: (@Sendable (URLRequest) throws -> StubResponse)?
  func set(_ handler: @escaping @Sendable (URLRequest) throws -> StubResponse) {
    lock.withLock { self.handler = handler }
  }
  func call(_ request: URLRequest) throws -> StubResponse {
    try lock.withLock { try handler!(request) }
  }
}

private final class StubProtocol: URLProtocol, @unchecked Sendable {
  static let handler = StubHandler()
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    do {
      let response = try Self.handler.call(request)
      client?.urlProtocol(
        self,
        didReceive: HTTPURLResponse(
          url: request.url!, statusCode: response.status, httpVersion: nil, headerFields: nil)!,
        cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: Data(response.body.utf8))
      client?.urlProtocolDidFinishLoading(self)
    } catch { client?.urlProtocol(self, didFailWithError: error) }
  }
  override func stopLoading() {}
}
