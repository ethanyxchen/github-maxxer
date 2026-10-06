import AppKit
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

  static func key(_ organization: String) -> String { organization.lowercased() }

  func keeping(_ organizations: Set<String>) -> OrganizationPreferences {
    var seen = Set<String>()
    return OrganizationPreferences(
      pinned: pinned.map(Self.key).filter {
        organizations.contains($0) && seen.insert($0).inserted
      },
      hidden: Set(hidden.map(Self.key)).intersection(organizations),
      names: Dictionary(names.map { (Self.key($0.key), $0.value) }) { first, _ in first }
        .filter { organizations.contains($0.key) })
  }
}

struct Landing: Equatable {
  static let celebration: TimeInterval = 2.5
  let pullRequests: Set<String>
  let date: Date
  let reveal: Date
}

struct Targets: Codable {
  var personal = Goals()
  var organizations: [String: Goals] = [:]
}

private struct SavedState: Codable {
  var targets = Targets()
  var connections: [AccountConnection] = []
  var organizations = OrganizationPreferences()
}

extension SavedState {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    targets = try container.decodeIfPresent(Targets.self, forKey: .targets) ?? Targets()
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
  private(set) var targets = Targets()
  private(set) var organizationPreferences = OrganizationPreferences()
  private(set) var isRefreshing = false
  private(set) var isConnecting = false
  private(set) var connectionErrors: [UUID: String] = [:]
  private(set) var storageError: String?
  private(set) var now = Date.now
  private(set) var landing: Landing?
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
      targets = Targets(personal: Goals(daily: 2), organizations: ["northstar": Goals(daily: 3)])
    } else if FileManager.default.fileExists(atPath: self.stateURL.path) {
      do {
        let state = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: self.stateURL))
        targets = state.targets
        connections = state.connections
        organizationPreferences = state.organizations
        pruneForgottenOrganizations()
      } catch {
        storageError = "Saved activity could not be loaded. \(error.localizedDescription)"
      }
    }
  }

  var pullRequests: [MergedPullRequest] {
    let pending = landing.flatMap { $0.reveal > now ? $0.pullRequests : nil } ?? []
    return merged.filter { !pending.contains($0.id) }
  }

  private var merged: [MergedPullRequest] {
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
    let owners = repositories.filter { $0.ownerKind == .organization }.map(\.owner)
    return Dictionary(owners.map { (OrganizationPreferences.key($0), $0) }) { first, _ in first }
      .values.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
  }

  var sidebarOrganizations: [String] {
    let visible = organizations.filter { !isHidden($0) }
    return organizationPreferences.pinned.compactMap { key in
      visible.first { OrganizationPreferences.key($0) == key }
    } + visible.filter { !isPinned($0) }
  }

  var workspaces: [ActivityFilter] {
    [.personal]
      + (sidebarOrganizations + organizations.filter(isHidden)).map(ActivityFilter.organization)
  }

  func title(for filter: ActivityFilter) -> String {
    guard case .organization(let owner) = filter else { return filter.title }
    return displayName(for: owner)
  }

  func goals(for filter: ActivityFilter) -> Goals {
    switch filter {
    case .all: Goals(daily: workspaces.map { goals(for: $0).daily }.reduce(0, +))
    case .personal: targets.personal
    case .organization(let owner):
      targets.organizations[OrganizationPreferences.key(owner)] ?? Goals()
    }
  }

  func setDailyGoal(_ value: Int, for filter: ActivityFilter) {
    let goals = Goals(clamping: value)
    switch filter {
    case .all: return
    case .personal: targets.personal = goals
    case .organization(let owner):
      targets.organizations[OrganizationPreferences.key(owner)] = goals
    }
    persist()
  }

  func displayName(for organization: String) -> String {
    organizationPreferences.names[OrganizationPreferences.key(organization)] ?? organization
  }

  func isPinned(_ organization: String) -> Bool {
    organizationPreferences.pinned.contains(OrganizationPreferences.key(organization))
  }

  func isHidden(_ organization: String) -> Bool {
    organizationPreferences.hidden.contains(OrganizationPreferences.key(organization))
  }

  func setPinned(_ pinned: Bool, organization: String) {
    let key = OrganizationPreferences.key(organization)
    organizationPreferences.pinned.removeAll { $0 == key }
    if pinned { organizationPreferences.pinned.append(key) }
    persist()
  }

  func setHidden(_ hidden: Bool, organization: String) {
    let key = OrganizationPreferences.key(organization)
    if hidden {
      organizationPreferences.hidden.insert(key)
    } else {
      organizationPreferences.hidden.remove(key)
    }
    persist()
  }

  func renameOrganization(_ organization: String, to name: String) {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    organizationPreferences.names[OrganizationPreferences.key(organization)] =
      name.isEmpty ? nil : name
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
    GoalProgress(
      count: pullRequests(for: period, filter: filter).count, target: goals(for: filter)[period])
  }

  func pullRequests(for period: GoalPeriod, filter: ActivityFilter = .all)
    -> [MergedPullRequest]
  {
    period.pullRequests(in: pullRequests(for: filter), now: now)
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

  func refresh() async {
    now = .now
    guard !isPreview, !isRefreshing, !isConnecting, !connections.isEmpty else { return }
    isRefreshing = true
    defer { isRefreshing = false }
    let accounts = connections
    let started = Date.now
    for account in accounts {
      if isConnecting { break }
      let requestedAt = Date.now
      do {
        try Task.checkCancellation()
        let token = try credentials.read(for: account.id)
        let snapshot = try await GitHubClient(token: token, session: session).snapshot(
          login: account.profile.login, now: requestedAt)
        guard let index = connections.firstIndex(where: { $0.id == account.id }) else { continue }
        if connections[index].snapshot.fetchedAt <= snapshot.fetchedAt {
          let known = Set(merged.map(\.id))
          connections[index].snapshot = snapshot
          land(Set(merged.map(\.id)).subtracting(known), since: started)
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

  private func land(_ arrived: Set<String>, since started: Date) {
    guard !arrived.isEmpty else { return }
    if let landing, landing.date >= started {
      self.landing = Landing(
        pullRequests: landing.pullRequests.union(arrived), date: landing.date,
        reveal: landing.reveal)
      return
    }
    let date = Date.now
    let delay =
      NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : Landing.celebration
    landing = Landing(pullRequests: arrived, date: date, reveal: date.addingTimeInterval(delay))
    Task {
      try? await Task.sleep(for: .seconds(delay))
      now = .now
    }
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

  private func pruneForgottenOrganizations() {
    guard !connections.isEmpty else { return }
    let owners = connections.flatMap {
      $0.snapshot.repositories + $0.snapshot.pullRequests.map(\.repository)
    }
    let keys = Set(owners.map { OrganizationPreferences.key($0.owner) })
    organizationPreferences = organizationPreferences.keeping(keys)
    targets.organizations = targets.organizations.filter { keys.contains($0.key) }
  }

  private func persist() {
    guard !isPreview else { return }
    pruneForgottenOrganizations()
    do {
      let directory = stateURL.deletingLastPathComponent()
      try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
      let state = SavedState(
        targets: targets, connections: connections, organizations: organizationPreferences)
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
