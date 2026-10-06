import GitHubMaxxerCore
import SwiftUI

private enum Destination: Hashable {
  case activity(ActivityFilter)
  case repositories, settings

  var title: String {
    switch self {
    case .activity(let filter): filter.title
    case .repositories: "Repositories"
    case .settings: "Targets & Accounts"
    }
  }

  var symbol: String {
    switch self {
    case .activity(.all): "square.stack"
    case .activity(.personal): "person"
    case .activity(.organization): "building.2"
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
  @State private var renaming: String?
  @State private var newName = ""

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        section("Activity") {
          row(.activity(.all))
          row(.activity(.personal))
          ForEach(model.sidebarOrganizations, id: \.self) { owner in
            row(.activity(.organization(owner))).contextMenu { organizationMenu(owner) }
          }
        }
        section("Manage") {
          row(.repositories)
          row(.settings)
        }
      }
      .scrollContentBackground(.hidden)
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
      .navigationTitle(title(for: selection))
      .toolbar(removing: .title)
      .toolbar {
        ToolbarSpacer(.flexible)
        ToolbarItem(placement: .primaryAction) {
          Button {
            Task { await model.refresh() }
          } label: {
            if model.isRefreshing {
              ProgressView().controlSize(.small)
            } else {
              Label("Refresh", systemImage: "arrow.clockwise")
            }
          }
          .keyboardShortcut("r", modifiers: .command)
          .disabled(
            model.isRefreshing || model.isConnecting || model.connections.isEmpty || model.isPreview
          )
          .help(model.isRefreshing ? "Refreshing GitHub activity" : "Refresh GitHub activity (⌘R)")
        }
      }
    }
    .navigationSplitViewStyle(.balanced)
    .overlay { HammerSlam(landing: model.landing) }
    .sheet(item: $connectionDraft) { draft in
      ConnectionSheet(existing: draft.existing)
        .environment(model)
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await model.refresh() } }
    }
    .alert(
      "Rename \(renaming ?? "")",
      isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    ) {
      TextField("Name", text: $newName)
      Button("Rename") {
        if let renaming { model.renameOrganization(renaming, to: newName) }
      }
      .keyboardShortcut(.defaultAction)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("The new name only appears in Hammertime.")
    }
    .onChange(of: model.sidebarOrganizations) { _, organizations in
      if case .activity(.organization(let owner)) = selection, !organizations.contains(owner) {
        selection = .activity(.all)
      }
    }
    .onAppear { model.startRefreshing() }
    .frame(minWidth: 920, minHeight: 680)
  }

  private func section(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
    Section {
      rows()
    } header: {
      Eyebrow(title).padding(.horizontal, 10).listRowInsets(EdgeInsets())
    }
  }

  private func row(_ destination: Destination) -> some View {
    SidebarRow(
      destination: destination, title: title(for: destination),
      isPinned: isPinned(destination), isSelected: selection == destination
    )
    .tag(destination)
    .listRowInsets(EdgeInsets())
    .listRowBackground(Palette.sidebar)
  }

  private func title(for destination: Destination) -> String {
    guard case .activity(let filter) = destination else { return destination.title }
    return model.title(for: filter)
  }

  private func isPinned(_ destination: Destination) -> Bool {
    guard case .activity(.organization(let owner)) = destination else { return false }
    return model.isPinned(owner)
  }

  @ViewBuilder
  private func organizationMenu(_ owner: String) -> some View {
    Button(model.isPinned(owner) ? "Unpin" : "Pin to Top") {
      model.setPinned(!model.isPinned(owner), organization: owner)
    }
    Button("Rename…") {
      newName = model.displayName(for: owner)
      renaming = owner
    }
    if model.displayName(for: owner) != owner {
      Button("Reset Name") { model.renameOrganization(owner, to: "") }
    }
    Divider()
    Button(role: .destructive) {
      model.setHidden(true, organization: owner)
    } label: {
      Text("Remove from Sidebar").foregroundStyle(.red)
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
        ActivityView(filter: filter, title: title(for: selection)).id(filter)
      }
    case .repositories:
      VStack(spacing: 0) {
        PageTitle(title(for: selection)).padding([.horizontal, .top], 20)
        RepositoriesView()
      }
    case .settings:
      VStack(spacing: 0) {
        PageTitle(title(for: selection)).padding([.horizontal, .top], 20)
        SettingsView { existing in connectionDraft = ConnectionDraft(existing: existing) }
      }
    }
  }
}

private struct SidebarRow: View {
  let destination: Destination
  let title: String
  let isPinned: Bool
  let isSelected: Bool
  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: destination.symbol)
        .frame(width: 18)
        .foregroundStyle(isSelected ? Palette.panel : Palette.secondary)
      Text(title).lineLimit(1)
      Spacer(minLength: 0)
      if isPinned {
        Image(systemName: "pin.fill").font(.system(size: 9))
          .foregroundStyle(isSelected ? Palette.panel : Palette.secondary)
          .accessibilityLabel("Pinned")
      }
    }
    .foregroundStyle(isSelected ? Palette.panel : Palette.ink)
    .fontWeight(isSelected ? .semibold : .regular)
    .padding(.horizontal, 10).frame(height: 30)
    .background(
      isSelected ? Palette.ink : isHovering ? Palette.ink.opacity(0.06) : .clear,
      in: RoundedRectangle(cornerRadius: 3)
    )
    .contentShape(Rectangle())
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
