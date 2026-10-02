import Foundation
import GitHubMaxxerCore
import Testing

@testable import GitHubMaxxer

@MainActor
struct AppModelTests {
  @Test func signingInAgainUpdatesAccountByGitHubID() async throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "state.json")
    let sample = PreviewData.connections(now: .now)[0]
    let connection = AccountConnection(
      id: UUID(), label: "Work", profile: sample.profile,
      scope: RepositoryScope(allRepositories: false, owners: ["northstar"]),
      snapshot: sample.snapshot)
    try JSONEncoder().encode(FixtureState(goals: Goals(), connections: [connection])).write(to: url)
    let store = TestCredentials()
    try store.save("oauth-credential", for: connection.id)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SignedInProtocol.self]
    let model = AppModel(
      stateURL: url, credentials: store, session: URLSession(configuration: configuration))

    try await model.connect(token: "cli-credential", label: "")

    #expect(model.connections.count == 1)
    #expect(model.connections[0].id == connection.id)
    #expect(model.connections[0].profile.login == "renamed-user")
    #expect(model.connections[0].scope == connection.scope)
    #expect(model.connections[0].label == connection.label)
    #expect(try store.read(for: connection.id) == "cli-credential")
    let reloaded = AppModel(stateURL: url, credentials: TestCredentials())
    #expect(reloaded.connections.count == 1)
    #expect(reloaded.connections[0].id == connection.id)
  }

  @Test func dailyGoalUpdatesWeeklyAndMonthlyTargets() throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "state.json")
    let model = AppModel(stateURL: url, credentials: TestCredentials())
    model.setDailyGoal(3)
    #expect(model.progress(for: .day).target == 3)
    #expect(model.progress(for: .week).target == 15)
    #expect(model.progress(for: .month).target == 60)
    let reloaded = AppModel(stateURL: url, credentials: TestCredentials())
    #expect(reloaded.goals.daily == 3)
    #expect(reloaded.goals.weekly == 15)
    #expect(reloaded.goals.monthly == 60)
    let state = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    let savedGoals = state["goals"] as! [String: Any]
    #expect(Set(savedGoals.keys) == ["daily"])
  }

  @Test func goalsSurviveRelaunchAndStayPositive() throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "state.json")
    let model = AppModel(stateURL: url, credentials: TestCredentials())
    model.setDailyGoal(-4)
    let reloaded = AppModel(stateURL: url, credentials: TestCredentials())
    #expect(reloaded.goals.weekly == 5)
    #expect(reloaded.goals.monthly == 20)
    #expect(reloaded.goals.daily == 1)
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    #expect(attributes[.posixPermissions] as? Int == 0o600)
  }

  @Test func previewNeverWritesAccountState() {
    let url = URL.temporaryDirectory.appending(path: UUID().uuidString).appending(
      path: "state.json")
    let model = AppModel(preview: true, stateURL: url, credentials: TestCredentials())
    model.setDailyGoal(3)
    model.setScope(RepositoryScope(allRepositories: false), for: model.connections[0].id)
    #expect(!FileManager.default.fileExists(atPath: url.path))
  }

  @Test func disconnectRemovesCredentialAndSavedActivity() throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "state.json")
    let connection = PreviewData.connections(now: .now)[0]
    try JSONEncoder().encode(FixtureState(goals: Goals(), connections: [connection])).write(to: url)
    let store = TestCredentials()
    try store.save("test-credential", for: connection.id)
    let model = AppModel(stateURL: url, credentials: store)

    try model.remove(connection.id)

    #expect(model.connections.isEmpty)
    #expect(store.tokens[connection.id] == nil)
    #expect(AppModel(stateURL: url, credentials: store).connections.isEmpty)
  }

  @Test func onlyExplicitRefreshAllowsCredentialInteraction() async throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "state.json")
    let connection = PreviewData.connections(now: .now)[0]
    try JSONEncoder().encode(FixtureState(goals: Goals(), connections: [connection])).write(to: url)
    let store = TestCredentials()
    try store.save("test-credential", for: connection.id)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [UnavailableProtocol.self]
    let model = AppModel(
      stateURL: url, credentials: store, session: URLSession(configuration: configuration))

    await model.refresh()
    await model.refresh(authorizeKeychain: true)

    #expect(store.readInteractions == [false, true])
  }

  @Test func failedRefreshPreservesSnapshotAndReportsError() async throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "state.json")
    let connections = PreviewData.connections(now: .now)
    let state = FixtureState(goals: Goals(), connections: connections)
    try JSONEncoder().encode(state).write(to: url)
    let store = TestCredentials()
    let id = connections[0].id
    try store.save("test-credential", for: id)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [UnavailableProtocol.self]
    let model = AppModel(
      stateURL: url, credentials: store, session: URLSession(configuration: configuration))
    let before = model.pullRequests
    let updated = model.lastUpdated
    await model.refresh()
    #expect(model.pullRequests == before)
    #expect(model.lastUpdated == updated)
    #expect(model.connectionErrors[id]?.contains("503") == true)
    #expect(!model.isRefreshing)
    let reloaded = AppModel(stateURL: url, credentials: TestCredentials())
    #expect(reloaded.pullRequests == before)
  }
}

@MainActor
private final class TestCredentials: CredentialStorage {
  var tokens: [UUID: String] = [:]
  var readInteractions: [Bool] = []

  func save(_ token: String, for id: UUID) throws {
    tokens[id] = token
  }

  func read(for id: UUID, allowInteraction: Bool = false) throws -> String {
    readInteractions.append(allowInteraction)
    guard let token = tokens[id] else { throw CredentialError.invalidData }
    return token
  }

  func delete(for id: UUID) throws {
    tokens[id] = nil
  }
}

private struct FixtureState: Encodable {
  let goals: Goals
  let connections: [AccountConnection]
}

private final class SignedInProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    do {
      let query = try requestBody(request)["query"] as! String
      let body: String
      if query.contains("contributionsCollection") {
        body = """
          {"data":{"viewer":{"contributionsCollection":{"contributionCalendar":{"totalContributions":0,"weeks":[]}}}}}
          """
      } else if query.contains("repositories(first") {
        body = """
          {"data":{"viewer":{"repositories":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}
          """
      } else if query.contains("search(query") {
        body = """
          {"data":{"search":{"issueCount":0,"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}
          """
      } else {
        body = """
          {"data":{"viewer":{"id":"preview-user","login":"renamed-user","name":null,"avatarUrl":"https://github.com/renamed-user.png"}}}
          """
      }
      client?.urlProtocol(
        self,
        didReceive: HTTPURLResponse(
          url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: Data(body.utf8))
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }
  override func stopLoading() {}
}

private final class UnavailableProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    client?.urlProtocol(
      self,
      didReceive: HTTPURLResponse(
        url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!,
      cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data("{}".utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}
