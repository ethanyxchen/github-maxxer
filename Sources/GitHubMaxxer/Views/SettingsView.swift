import GitHubMaxxerCore
import SwiftUI

struct SettingsView: View {
  @Environment(AppModel.self) private var model
  var connect: ((AccountConnection?) -> Void)?
  @State private var draft: ConnectionDraft?
  @State private var removing: AccountConnection?
  @State private var removalError: String?

  private var dailyGoal: Binding<Int> {
    Binding(get: { model.goals.daily }, set: { model.setDailyGoal($0) })
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        SettingsSection(
          "Merged PR targets",
          footer:
            "Weekly and monthly targets follow your daily target: 5 days per week and 20 days per month. PRs count on their merge date, using your Mac's time zone. Weeks run Monday through Sunday. Each PR counts once across all connections."
        ) {
          ForEach(GoalPeriod.allCases) { period in
            HStack {
              Text(period.targetLabel)
              Spacer()
              if period == .day {
                TextField("Pull requests", value: dailyGoal, format: .number.grouping(.never))
                  .labelsHidden().accessibilityLabel(period.targetLabel)
                  .textFieldStyle(.plain)
                  .multilineTextAlignment(.trailing).frame(width: 56)
                  .monospacedDigit()
                Stepper(period.targetLabel, value: dailyGoal, in: Goals.dailyRange)
                  .labelsHidden().fixedSize()
              } else {
                Text(model.goals[period], format: .number.grouping(.never))
                  .monospacedDigit()
              }
              Text("PRs").foregroundStyle(.secondary).frame(width: 28, alignment: .leading)
            }
          }
        }
        SettingsSection(
          "GitHub connections",
          footer:
            "Connect personal and work accounts. Signing in to the same account again updates its credential and keeps your repository selections. Credentials are stored in macOS Keychain. Activity is saved locally so it stays available offline."
        ) {
          ForEach(model.connections) { connection in
            VStack(alignment: .leading, spacing: 10) {
              HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                  .font(.title).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                  ConnectionNameField(connection: connection)
                  Link("@\(connection.profile.login)", destination: connection.profileURL)
                    .font(.callout)
                }
                Spacer()
                Menu {
                  Button("Reconnect…") { showConnection(connection) }
                  Divider()
                  Button("Disconnect…", role: .destructive) { removing = connection }
                } label: {
                  Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton).fixedSize().disabled(model.isPreview)
                .accessibilityLabel("Manage \(connection.label)")
              }
              if let error = model.connectionErrors[connection.id] {
                Label(error, systemImage: "exclamationmark.circle")
                  .font(.caption).foregroundStyle(.orange).textSelection(.enabled)
              }
            }
          }
          Button {
            showConnection(nil)
          } label: {
            Label("Add GitHub connection…", systemImage: "plus")
          }
          .disabled(model.isPreview)
        }
        SettingsSection("Updates") {
          LabeledContent("Refresh", value: "Every minute while the app is running")
          LabeledContent("History", value: "Merged PRs from the last 90 days")
        }
      }
      .padding(20)
    }
    .sheet(item: $draft) { ConnectionSheet(existing: $0.existing).environment(model) }
    .confirmationDialog(
      "Disconnect \(removing?.label ?? "GitHub")?",
      isPresented: Binding(
        get: { removing != nil }, set: { if !$0 { removing = nil } }
      ), titleVisibility: .visible
    ) {
      Button("Disconnect", role: .destructive) {
        if let removing {
          do { try model.remove(removing.id) } catch { removalError = error.localizedDescription }
        }
        removing = nil
      }
    } message: {
      Text("This removes the saved credential and activity for this connection from your Mac.")
    }
    .alert(
      "Could not disconnect",
      isPresented: Binding(
        get: { removalError != nil }, set: { if !$0 { removalError = nil } }
      )
    ) {
      Button("OK") { removalError = nil }
    } message: {
      Text(removalError ?? "")
    }
  }

  private func showConnection(_ existing: AccountConnection?) {
    if let connect { connect(existing) } else { draft = ConnectionDraft(existing: existing) }
  }
}

private struct SettingsSection<Content: View>: View {
  let title: String
  var footer: String?
  let content: Content
  private let inset: CGFloat = 10

  init(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.footer = footer
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.headline)
      VStack(alignment: .leading, spacing: 0) {
        Group(subviews: content) { rows in
          ForEach(rows) { row in
            if row.id != rows.first?.id { Divider() }
            row.padding(.vertical, 12)
          }
        }
      }
      .labeledContentStyle(SettingsRowStyle())
      .padding(.horizontal, inset)
      .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 10))
      if let footer {
        Text(footer).font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, inset)
      }
    }
  }
}

private struct SettingsRowStyle: LabeledContentStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack {
      configuration.label
      Spacer()
      configuration.content.foregroundStyle(.secondary)
    }
  }
}

private struct ConnectionNameField: View {
  @Environment(AppModel.self) private var model
  let connection: AccountConnection
  @State private var name: String
  @FocusState private var isFocused: Bool

  init(connection: AccountConnection) {
    self.connection = connection
    _name = State(initialValue: connection.label)
  }

  var body: some View {
    TextField("Connection name", text: $name)
      .labelsHidden().accessibilityLabel("Connection name")
      .textFieldStyle(.plain).font(.headline)
      .focused($isFocused)
      .onSubmit { model.rename(name, id: connection.id) }
      .onChange(of: isFocused) { _, focused in
        if !focused { model.rename(name, id: connection.id) }
      }
      .onDisappear { model.rename(name, id: connection.id) }
  }
}
