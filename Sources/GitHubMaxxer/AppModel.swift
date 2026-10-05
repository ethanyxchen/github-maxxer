import Foundation
import GitHubMaxxerCore
import Observation

struct AccountConnection: Codable, Identifiable {
  let id: UUID
  var label: String
  var profile: GitHubProfile
  var scope: RepositoryScope
  var snapshot: GitHubSnapshot

  var profileURL: URL { URL(string: "https://github.com/\(profile.login)")! }
}

struct OrganizationPreferences: Codable {
  var pinned: [String] = []
  var hidden: Set<String> = []
  var names: [String: String] = [:]
}

private struct SavedState: Codable {
  var goals = Goals()
  var connections: [AccountConnection] = []
  var organizations = OrganizationPreferences()
}

extension SavedState {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    goals = try container.decode(Goals.self, forKey: .goals)
    connections = try container.decode([AccountConnection].self, forKey: .connections)
    organizations =
      try container.decodeIfPresent(OrganizationPreferences.self, forKey: .organizations)
      ?? OrganizationPreferences()
  }
}

@MainActor
@Observable
final class AppModel {
  private(set) var connections: [AccountConnection] = []
  private(set) var goals = Goals()
  private(set) var organizationPreferences = OrganizationPreferences()
  private(set) var isRefreshing = false
  private(set) var isConnecting = false
  private(set) var connectionErrors: [UUID: String] = [:]
  private(set) var storageError: String?
  private(set) var now = Date.now
  let isPreview: Bool
  private let credentials: any CredentialStorage
  private let session: URLSession
  private let stateURL: URL
  private var refreshTask: Task<Void, Never>?

  init(
    preview: Bool = false, stateURL: URL? = nil,
    credentials: any CredentialStorage = CredentialStore(),
    session: URLSession = .shared
  ) {
    isPreview = preview
    self.credentials = credentials
    self.session = session
    self.stateURL =
      stateURL
      ?? URL.applicationSupportDirectory
      .appending(path: "GitHub Maxxer", directoryHint: .isDirectory)
      .appending(path: "state.json")
    if preview {
      connections = PreviewData.connections(now: now)
      goals = Goals(daily: 2)
    } else if FileManager.default.fileExists(atPath: self.stateURL.path) {
      do {
        let state = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: self.stateURL))
        goals = state.goals
        connections = state.connections
        organizationPreferences = state.organizations
      } catch {
        storageError = "Saved activity could not be loaded. \(error.localizedDescription)"
      }
    }
  }

  var pullRequests: [MergedPullRequest] {
    let interval = Activity.historyInterval(endingAt: now)
    return Activity.mergedPullRequests(
      from: connections.map {
        ScopedActivity(pullRequests: $0.snapshot.pullRequests, scope: $0.scope)
      }
    ).filter { interval.contains($0.mergedAt) }
  }

  var organizations: [String] {
    let repositories = connections.flatMap { account in
      account.snapshot.repositories.filter { account.scope.includes($0) }
        + account.snapshot.pullRequests.map(\.repository).filter { account.scope.includes($0) }
    }
    return Array(Set(repositories.filter { $0.ownerKind == .organization }.map(\.owner)))
      .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
  }

  var sidebarOrganizations: [String] {
    let visible = organizations.filter { !organizationPreferences.hidden.contains($0) }
    return organizationPreferences.pinned.filter(visible.contains)
      + visible.filter { !organizationPreferences.pinned.contains($0) }
  }

  func displayName(for organization: String) -> String {
    organizationPreferences.names[organization] ?? organization
  }

  func isPinned(_ organization: String) -> Bool {
    organizationPreferences.pinned.contains(organization)
  }

  func isHidden(_ organization: String) -> Bool {
    organizationPreferences.hidden.contains(organization)
  }

  func setPinned(_ pinned: Bool, organization: String) {
    organizationPreferences.pinned.removeAll { $0 == organization }
    if pinned { organizationPreferences.pinned.append(organization) }
    persist()
  }

  func setHidden(_ hidden: Bool, organization: String) {
    if hidden {
      organizationPreferences.hidden.insert(organization)
    } else {
      organizationPreferences.hidden.remove(organization)
    }
    persist()
  }

  func renameOrganization(_ organization: String, to name: String) {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    organizationPreferences.names[organization] = name.isEmpty ? nil : name
    persist()
  }

  func pullRequests(for filter: ActivityFilter) -> [MergedPullRequest] {
    filter.pullRequests(in: pullRequests, personalLogins: Set(connections.map(\.profile.login)))
  }

  var trackedRepositoryCount: Int {
    Set(
      connections.flatMap { account in
        account.snapshot.repositories.filter { account.scope.includes($0) }.map(\.id)
      }
    ).count
  }

  var lastUpdated: Date? { connections.map { $0.snapshot.fetchedAt }.min() }
  var errors: [String] {
    (storageError.map { [$0] } ?? [])
      + connections.compactMap { account in
        connectionErrors[account.id].map { "\(account.label): \($0)" }
      }
  }

  func progress(for period: GoalPeriod, filter: ActivityFilter = .all) -> GoalProgress {
    GoalProgress(count: pullRequests(for: period, filter: filter).count, target: goals[period])
  }

  func pullRequests(for period: GoalPeriod, filter: ActivityFilter = .all)
    -> [MergedPullRequest]
  {
    period.pullRequests(in: pullRequests(for: filter), now: now)
  }

  func setDailyGoal(_ value: Int) {
    goals = Goals(daily: value)
    persist()
  }

  func setScope(_ scope: RepositoryScope, for id: UUID) {
    guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
    connections[index].scope = scope
    persist()
  }

  func rename(_ label: String, id: UUID) {
    guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
    let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
    connections[index].label = name.isEmpty ? connections[index].profile.login : name
    persist()
  }

  func connect(token: String, label: String, replacing id: UUID? = nil) async throws {
    guard !isPreview else { return }
    guard !isConnecting else { throw ConnectionError.busy }
    isConnecting = true
    defer { isConnecting = false }
    let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
    let client = GitHubClient(token: token, session: session)
    let profile = try await client.profile()
    if let existing = connections.first(where: { $0.id == id }), existing.profile.id != profile.id {
      throw ConnectionError.wrongAccount(existing.profile.login)
    }
    let connectionID =
      id ?? connections.first { $0.profile.id == profile.id }?.id ?? UUID()
    let snapshot = try await client.snapshot(login: profile.login)
    try Task.checkCancellation()
    try credentials.save(token, for: connectionID)
    let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
    if let index = connections.firstIndex(where: { $0.id == connectionID }) {
      connections[index].profile = profile
      connections[index].snapshot = snapshot
      if !name.isEmpty { connections[index].label = name }
    } else {
      connections.append(
        AccountConnection(
          id: connectionID, label: name.isEmpty ? profile.login : name,
          profile: profile, scope: RepositoryScope(), snapshot: snapshot
        ))
    }
    connectionErrors[connectionID] = nil
    now = .now
    persist()
  }

  func remove(_ id: UUID) throws {
    if !isPreview { try credentials.delete(for: id) }
    connections.removeAll { $0.id == id }
    connectionErrors[id] = nil
    persist()
  }

  func refresh(authorizeKeychain: Bool = false) async {
    now = .now
    guard !isPreview, !isRefreshing, !isConnecting, !connections.isEmpty else { return }
    isRefreshing = true
    defer { isRefreshing = false }
    let accounts = connections
    for account in accounts {
      if isConnecting { break }
      let requestedAt = Date.now
      do {
        try Task.checkCancellation()
        let token = try credentials.read(for: account.id, allowInteraction: authorizeKeychain)
        let snapshot = try await GitHubClient(token: token, session: session).snapshot(
          login: account.profile.login, now: requestedAt)
        guard let index = connections.firstIndex(where: { $0.id == account.id }) else { continue }
        if connections[index].snapshot.fetchedAt <= snapshot.fetchedAt {
          connections[index].snapshot = snapshot
        }
        connectionErrors[account.id] = nil
      } catch is CancellationError {
        return
      } catch {
        guard let current = connections.first(where: { $0.id == account.id }),
          current.snapshot.fetchedAt <= requestedAt
        else { continue }
        connectionErrors[account.id] = error.localizedDescription
      }
    }
    persist()
  }

  func startRefreshing() {
    guard refreshTask == nil, !isPreview else { return }
    refreshTask = Task { await runRefreshLoop() }
  }

  private func runRefreshLoop() async {
    await refresh()
    while !Task.isCancelled {
      do { try await Task.sleep(for: .seconds(60)) } catch { return }
      await refresh()
    }
  }

  private func persist() {
    guard !isPreview else { return }
    do {
      let directory = stateURL.deletingLastPathComponent()
      try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
      let state = SavedState(
        goals: goals, connections: connections, organizations: organizationPreferences)
      try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateURL.path)
      storageError = nil
    } catch {
      storageError = "Changes could not be saved. \(error.localizedDescription)"
    }
  }
}

private enum ConnectionError: LocalizedError {
  case wrongAccount(String)
  case busy
  var errorDescription: String? {
    switch self {
    case .busy: "Another GitHub connection is loading. Wait for it to finish, then try again."
    case .wrongAccount(let login):
      "You signed in to a different account. Reconnect @\(login), or add it as a new connection."
    }
  }
}
