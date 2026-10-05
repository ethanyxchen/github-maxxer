import GitHubMaxxerCore
import SwiftUI

private enum Destination: Hashable {
  case activity(ActivityFilter)
  case history, repositories, settings

  var title: String {
    switch self {
    case .activity(let filter): filter.title
    case .history: "History"
    case .repositories: "Repositories"
    case .settings: "Targets & Accounts"
    }
  }

  var symbol: String {
    switch self {
    case .activity(.all): "square.stack"
    case .activity(.personal): "person"
    case .activity(.organization): "building.2"
    case .history: "calendar"
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
  @State private var selection: Destination = .activity(.all)
  @State private var connectionDraft: ConnectionDraft?

  var body: some View {
    NavigationSplitView {
      VStack(alignment: .leading, spacing: 22) {
        section("Activity") {
          row(.activity(.all))
          row(.activity(.personal))
          ForEach(model.organizations, id: \.self) { owner in
            row(.activity(.organization(owner)))
          }
        }
        section("Insights") { row(.history) }
        section("Manage") {
          row(.repositories)
          row(.settings)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 10).padding(.vertical, 12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Palette.sidebar)
      .background(SidebarResizeBehavior())
      .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 270)
      .safeAreaInset(edge: .bottom, spacing: 0) { sidebarFooter }
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
      .navigationTitle(selection.title)
      .toolbarBackground(.hidden, for: .windowToolbar)
      .toolbar {
        if model.isRefreshing {
          ToolbarItem { ProgressView().controlSize(.small).help("Refreshing GitHub activity") }
        }
        ToolbarItem {
          Button {
            Task { await model.refresh(authorizeKeychain: true) }
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
    }
    .navigationSplitViewStyle(.balanced)
    .sheet(item: $connectionDraft) { draft in
      ConnectionSheet(existing: draft.existing)
        .environment(model)
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await model.refresh() } }
    }
    .onChange(of: model.organizations) { _, organizations in
      if case .activity(.organization(let owner)) = selection, !organizations.contains(owner) {
        selection = .activity(.all)
      }
    }
    .onAppear { model.startRefreshing() }
    .frame(minWidth: 920, minHeight: 680)
  }

  private func section(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Eyebrow(title).padding(.horizontal, 10).padding(.bottom, 6)
      rows()
    }
  }

  private func row(_ destination: Destination) -> some View {
    SidebarRow(destination: destination, isSelected: selection == destination) {
      selection = destination
    }
  }

  @ViewBuilder
  private var sidebarFooter: some View {
    VStack(alignment: .leading, spacing: 0) {
      Rule()
      if model.connections.isEmpty {
        Button {
          connectionDraft = ConnectionDraft()
        } label: {
          Label("Connect GitHub", systemImage: "plus")
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(20)
        .disabled(model.isPreview)
      } else {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Lamp(isOn: model.errors.isEmpty && model.lastUpdated != nil)
            Text(
              model.connections.count == 1
                ? model.connections[0].label : "\(model.connections.count) accounts"
            )
            .fontWeight(.medium).lineLimit(1)
          }
          Group {
            if !model.errors.isEmpty {
              Text("Needs attention")
            } else if let date = model.lastUpdated {
              Text("Updated \(date, style: .relative) ago")
            } else {
              Text("Waiting for first update")
            }
            Text("\(model.trackedRepositoryCount) repositories")
          }
          .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.secondary)
          .padding(.leading, 15)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .accessibilityElement(children: .combine)
      }
    }
    .background(Palette.sidebar)
  }

  @ViewBuilder
  private var content: some View {
    switch selection {
    case .activity(let filter):
      if model.connections.isEmpty {
        WelcomeView { connectionDraft = ConnectionDraft() }
      } else {
        ActivityView(filter: filter).id(filter)
      }
    case .history:
      ScrollView {
        RecordView().padding(40).frame(maxWidth: 960, alignment: .leading)
      }
      .background(Palette.panel)
    case .repositories: RepositoriesView()
    case .settings:
      SettingsView { existing in connectionDraft = ConnectionDraft(existing: existing) }
    }
  }
}

private struct SidebarRow: View {
  let destination: Destination
  let isSelected: Bool
  let select: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: select) {
      HStack(spacing: 10) {
        Image(systemName: destination.symbol)
          .frame(width: 18)
          .foregroundStyle(isSelected ? Palette.panel : Palette.secondary)
        Text(destination.title).lineLimit(1)
        Spacer(minLength: 0)
      }
      .foregroundStyle(isSelected ? Palette.panel : Palette.ink)
      .fontWeight(isSelected ? .semibold : .regular)
      .padding(.horizontal, 10).frame(height: 30)
      .background(
        isSelected ? Palette.ink : isHovering ? Palette.ink.opacity(0.06) : .clear,
        in: RoundedRectangle(cornerRadius: 3)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

private struct WelcomeView: View {
  let connect: () -> Void

  var body: some View {
    VStack(spacing: 22) {
      Image(systemName: "arrow.triangle.pull")
        .font(.system(size: 46, weight: .light))
        .foregroundStyle(Palette.reached)
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
