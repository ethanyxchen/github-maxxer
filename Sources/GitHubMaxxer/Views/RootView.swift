import GitHubMaxxerCore
import SwiftUI

private enum Destination: String, CaseIterable, Identifiable {
  case overview, pullRequests, repositories, settings
  var id: String { rawValue }
  var title: String {
    switch self {
    case .overview: "Overview"
    case .pullRequests: "Pull Requests"
    case .repositories: "Repositories"
    case .settings: "Targets & Accounts"
    }
  }
  var symbol: String {
    switch self {
    case .overview: "chart.bar.xaxis"
    case .pullRequests: "arrow.triangle.pull"
    case .repositories: "folder"
    case .settings: "slider.horizontal.3"
    }
  }
}

struct ConnectionDraft: Identifiable {
  let id = UUID()
  var existing: AccountConnection?
}

struct RootView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase
  @State private var selection: Destination? = .overview
  @State private var connectionDraft: ConnectionDraft?

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Section("Activity") {
          navigationRow(.overview)
          navigationRow(.pullRequests)
        }
        Section("Manage") {
          navigationRow(.repositories)
          navigationRow(.settings)
        }
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 270)
      .safeAreaInset(edge: .bottom) {
        if model.connections.isEmpty {
          Button {
            connectionDraft = ConnectionDraft()
          } label: {
            Label("Connect GitHub", systemImage: "plus")
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 6)
          }
          .buttonStyle(.plain)
          .padding(16)
          .disabled(model.isPreview)
        }
      }
    } detail: {
      VStack(spacing: 0) {
        if model.isPreview {
          HStack {
            Label("Preview", systemImage: "eye")
            Text("Sample activity · no account connected").foregroundStyle(.secondary)
            Spacer()
          }
          .font(.caption).padding(.horizontal, 24).padding(.vertical, 8)
          .background(.quaternary)
        }
        if let error = model.errors.first {
          ErrorBanner(message: error, additionalCount: model.errors.count - 1)
        }
        content.frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .navigationTitle((selection ?? .overview).title)
      .toolbar {
        if model.isRefreshing {
          ToolbarItem { ProgressView().controlSize(.small).help("Refreshing GitHub activity") }
        }
        ToolbarItem {
          Button {
            Task { await model.refresh() }
          } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
          }
          .keyboardShortcut("r", modifiers: .command)
          .disabled(
            model.isRefreshing || model.isConnecting || model.connections.isEmpty || model.isPreview
          )
          .help("Refresh GitHub activity (⌘R)")
        }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        statusBar
      }
    }
    .sheet(item: $connectionDraft) { draft in
      ConnectionSheet(existing: draft.existing)
        .environment(model)
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await model.refresh() } }
    }
    .onAppear { model.startRefreshing() }
    .frame(minWidth: 920, minHeight: 680)
  }

  private func navigationRow(_ destination: Destination) -> some View {
    Label(destination.title, systemImage: destination.symbol).tag(destination)
  }

  @ViewBuilder
  private var content: some View {
    switch selection ?? .overview {
    case .overview:
      if model.connections.isEmpty {
        WelcomeView { connectionDraft = ConnectionDraft() }
      } else {
        OverviewView { selection = .pullRequests }
      }
    case .pullRequests: PullRequestsView()
    case .repositories: RepositoriesView()
    case .settings:
      SettingsView { existing in connectionDraft = ConnectionDraft(existing: existing) }
    }
  }

  private var statusBar: some View {
    HStack(spacing: 6) {
      if model.connections.isEmpty {
        Text("No GitHub account connected")
      } else {
        Image(systemName: model.errors.isEmpty ? "checkmark.circle" : "exclamationmark.circle")
          .foregroundStyle(model.errors.isEmpty ? Color.secondary : .orange)
        if let date = model.lastUpdated {
          Text("Updated \(date, style: .relative) ago")
        } else {
          Text("Waiting for first update")
        }
        Spacer()
        Text("\(model.trackedRepositoryCount) repositories · Refreshes every minute")
      }
    }
    .font(.caption).foregroundStyle(.secondary)
    .padding(.horizontal, 20).padding(.vertical, 9)
    .background(.bar)
    .accessibilityElement(children: .combine)
  }
}

private struct WelcomeView: View {
  let connect: () -> Void

  var body: some View {
    VStack(spacing: 22) {
      Image(systemName: "arrow.triangle.pull")
        .font(.system(size: 46, weight: .light))
        .foregroundStyle(.green)
      VStack(spacing: 9) {
        Text("Keep track of what you merge")
          .font(.system(size: 26, weight: .semibold))
        Text(
          "Set your PR targets and follow your GitHub activity,\nacross your personal projects and work repositories."
        )
        .foregroundStyle(.secondary).multilineTextAlignment(.center)
        .lineSpacing(4)
      }
      Button("Connect GitHub", action: connect)
        .buttonStyle(.borderedProminent).controlSize(.large)
      Label("Your credentials stay in macOS Keychain", systemImage: "lock")
        .font(.caption).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
  }
}

struct ErrorBanner: View {
  let message: String
  var additionalCount = 0

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
      VStack(alignment: .leading, spacing: 4) {
        Text(message).font(.callout).textSelection(.enabled)
        if additionalCount > 0 {
          Text("\(additionalCount) more connections need attention in Targets & Accounts.")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
    .background(.orange.opacity(0.08))
  }
}
