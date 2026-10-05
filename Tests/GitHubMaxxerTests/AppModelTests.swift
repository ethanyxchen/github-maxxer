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

  @Test func previewSeparatesOrganizationAndPersonalActivity() {
    let model = AppModel(preview: true)
    #expect(model.organizations == ["northstar"])
    let work = model.pullRequests(for: .organization("northstar"))
    let personal = model.pullRequests(for: .personal)
    #expect(!work.isEmpty)
    #expect(!personal.isEmpty)
    #expect(work.count + personal.count == model.pullRequests.count)
    #expect(
      model.progress(for: .month, filter: .organization("northstar")).count
        == GoalPeriod.month.count(in: work, now: model.now))
  }

  @Test func sidebarOrganizationsKeepPinsHiddenOwnersAndLocalNames() throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "state.json")
    let sample = PreviewData.connections(now: .now)[0]
    let repositories = ["acme/app", "beta/app"].map {
      Repository(id: $0, nameWithOwner: $0, isPrivate: false, ownerKind: .organization)
    }
    let merged = MergedPullRequest(
      id: "beta-1", title: "Ship", number: 1,
      url: URL(string: "https://github.com/beta/app/pull/1")!,
      mergedAt: .now.addingTimeInterval(-1), repository: repositories[1])
    let connection = AccountConnection(
      id: UUID(), label: "Work", profile: sample.profile, scope: RepositoryScope(),
      snapshot: GitHubSnapshot(repositories: repositories, pullRequests: [merged], fetchedAt: .now))
    try JSONEncoder().encode(FixtureState(goals: Goals(), connections: [connection])).write(to: url)
    let model = AppModel(stateURL: url, credentials: TestCredentials())
    #expect(model.sidebarOrganizations == ["acme", "beta"])

    model.setPinned(true, organization: "beta")
    model.renameOrganization("acme", to: "  Acme Inc  ")
    #expect(model.sidebarOrganizations == ["beta", "acme"])
    #expect(model.displayName(for: "acme") == "Acme Inc")
    model.setHidden(true, organization: "beta")
    #expect(model.sidebarOrganizations == ["acme"])

    let reloaded = AppModel(stateURL: url, credentials: TestCredentials())
    #expect(reloaded.sidebarOrganizations == ["acme"])
    #expect(reloaded.isPinned("beta"))
    #expect(reloaded.pullRequests(for: .all) == [merged])
    #expect(reloaded.progress(for: .day).count == 1)
    #expect(reloaded.displayName(for: "acme") == "Acme Inc")
    reloaded.renameOrganization("acme", to: " ")
    reloaded.setHidden(false, organization: "beta")
    #expect(reloaded.displayName(for: "acme") == "acme")
    #expect(reloaded.sidebarOrganizations == ["beta", "acme"])
  }

  @Test func organizationPreferencesIgnoreOwnerCase() throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "state.json")
    let sample = PreviewData.connections(now: .now)[0]
    let repositories = ["acme/app", "beta/app", "Beta/tools"].map {
      Repository(id: $0, nameWithOwner: $0, isPrivate: false, ownerKind: .organization)
    }
    let connection = AccountConnection(
      id: UUID(), label: "Work", profile: sample.profile, scope: RepositoryScope(),
      snapshot: GitHubSnapshot(repositories: repositories, pullRequests: [], fetchedAt: .now))
    let saved = OrganizationPreferences(
      pinned: ["Beta"], hidden: ["ACME"], names: ["Beta": "Beta Labs"])
    try JSONEncoder().encode(
      FixtureState(goals: Goals(), connections: [connection], organizations: saved)
    ).write(to: url)
    let model = AppModel(stateURL: url, credentials: TestCredentials())

    #expect(model.isPinned("beta"))
    #expect(model.isHidden("acme"))
    #expect(model.displayName(for: "beta") == "Beta Labs")
    #expect(model.sidebarOrganizations == ["beta"])

    model.setPinned(false, organization: "BETA")
    model.setHidden(false, organization: "Acme")
    model.renameOrganization("BeTa", to: "")
    #expect(!model.isPinned("beta"))
    #expect(model.displayName(for: "beta") == "beta")
    #expect(model.sidebarOrganizations == ["acme", "beta"])
  }

  @Test func organizationPreferencesForgetOrganizationsThatDisappear() throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "state.json")
    let sample = PreviewData.connections(now: .now)[0]
    let repository = Repository(
      id: "acme/app", nameWithOwner: "acme/app", isPrivate: false, ownerKind: .organization)
    let connection = AccountConnection(
      id: UUID(), label: "Work", profile: sample.profile,
      scope: RepositoryScope(allRepositories: false),
      snapshot: GitHubSnapshot(repositories: [repository], pullRequests: [], fetchedAt: .now))
    let saved = OrganizationPreferences(
      pinned: ["acme", "gone"], hidden: ["gone"], names: ["acme": "Acme", "gone": "Gone"])
    try JSONEncoder().encode(
      FixtureState(goals: Goals(), connections: [connection], organizations: saved)
    ).write(to: url)
    let model = AppModel(stateURL: url, credentials: TestCredentials())

    model.setDailyGoal(2)

    let reloaded = AppModel(stateURL: url, credentials: TestCredentials())
    #expect(reloaded.organizationPreferences.pinned == ["acme"])
    #expect(reloaded.organizationPreferences.hidden.isEmpty)
    #expect(reloaded.organizationPreferences.names == ["acme": "Acme"])

    try reloaded.remove(connection.id)

    let empty = AppModel(stateURL: url, credentials: TestCredentials())
    #expect(empty.organizationPreferences.pinned == ["acme"])
    #expect(empty.organizationPreferences.names == ["acme": "Acme"])
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
  var organizations: OrganizationPreferences?
}

private final class SignedInProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    do {
      let query = try requestBody(request)["query"] as! String
      let body: String
      if query.contains("repositories(first") {
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
