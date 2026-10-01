import Foundation
import GitHubMaxxerCore
import Testing

@testable import GitHubMaxxer

@MainActor
struct AppModelTests {
  @Test func dailyGoalUpdatesWeeklyAndMonthlyTargets() throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "state.json")
    let model = AppModel(stateURL: url)
    model.setDailyGoal(3)
    #expect(model.progress(for: .day).target == 3)
    #expect(model.progress(for: .week).target == 15)
    #expect(model.progress(for: .month).target == 60)
    let reloaded = AppModel(stateURL: url)
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
    let model = AppModel(stateURL: url)
    model.setDailyGoal(-4)
    let reloaded = AppModel(stateURL: url)
    #expect(reloaded.goals.weekly == 5)
    #expect(reloaded.goals.monthly == 20)
    #expect(reloaded.goals.daily == 1)
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    #expect(attributes[.posixPermissions] as? Int == 0o600)
  }

  @Test func previewNeverWritesAccountState() {
    let url = URL.temporaryDirectory.appending(path: UUID().uuidString).appending(
      path: "state.json")
    let model = AppModel(preview: true, stateURL: url)
    model.setDailyGoal(3)
    model.setScope(RepositoryScope(allRepositories: false), for: model.connections[0].id)
    #expect(!FileManager.default.fileExists(atPath: url.path))
  }

  @Test func keychainSupportsReplacementAndRemoval() throws {
    let store = CredentialStore(service: "com.ethanyxchen.github-maxxer.tests")
    let id = UUID()
    defer { try? store.delete(for: id) }
    try store.save("test-credential", for: id)
    #expect(try store.read(for: id) == "test-credential")
    try store.save("replacement", for: id)
    #expect(try store.read(for: id) == "replacement")
    try store.delete(for: id)
    #expect(throws: CredentialError.self) { try store.read(for: id) }
  }

  @Test func failedRefreshPreservesSnapshotAndReportsError() async throws {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "state.json")
    let connections = PreviewData.connections(now: .now)
    let state = FixtureState(goals: Goals(), connections: connections)
    try JSONEncoder().encode(state).write(to: url)
    let store = CredentialStore(service: "com.ethanyxchen.github-maxxer.tests")
    let id = connections[0].id
    try store.save("test-credential", for: id)
    defer { try? store.delete(for: id) }
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
    let reloaded = AppModel(stateURL: url)
    #expect(reloaded.pullRequests == before)
  }
}

private struct FixtureState: Encodable {
  let goals: Goals
  let connections: [AccountConnection]
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
