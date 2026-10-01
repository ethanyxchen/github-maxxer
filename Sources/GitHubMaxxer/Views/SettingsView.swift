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
    Form {
      Section {
        ForEach(GoalPeriod.allCases) { period in
          HStack {
            Text(period.targetLabel)
            Spacer()
            if period == .day {
              TextField("Pull requests", value: dailyGoal, format: .number.grouping(.never))
                .labelsHidden().accessibilityLabel(period.targetLabel)
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
          .padding(.vertical, 4)
        }
      } header: {
        Text("Merged PR targets")
      } footer: {
        Text(
          "Weekly and monthly targets follow your daily target: 5 days per week and 20 days per month. PRs count on their merge date, using your Mac's time zone. Weeks run Monday through Sunday. Each PR counts once across all connections."
        )
        .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
      }
      Section {
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
          .padding(.vertical, 6)
        }
        Button {
          showConnection(nil)
        } label: {
          Label("Add GitHub connection…", systemImage: "plus")
        }
        .disabled(model.isPreview)
      } header: {
        Text("GitHub connections")
      } footer: {
        Text(
          "Add personal and work accounts, or multiple connections for the same account. Credentials are stored in macOS Keychain. Activity is saved locally so it stays available offline."
        )
        .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
      }
      Section("Updates") {
        LabeledContent("Refresh", value: "Every minute while the app is running")
        LabeledContent("History", value: "Merged PRs from the last 90 days")
        LabeledContent("Contribution calendar", value: "Last year, directly from GitHub")
      }
    }
    .formStyle(.grouped)
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
