import GitHubMaxxerCore
import SwiftUI

struct ConnectionSheet: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  let existing: AccountConnection?
  @State private var error: String?
  @State private var connectionTask: Task<Void, Never>?
  @State private var cliMissing = false
  private let appBecameActive = NotificationCenter.default.publisher(
    for: NSApplication.didBecomeActiveNotification)

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 12) {
        Image(systemName: "person.crop.circle.badge.checkmark")
          .font(.system(size: 32, weight: .light)).foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 5) {
          Text(existing.map { "Reconnect @\($0.profile.login)" } ?? "Connect GitHub")
            .font(.title2.weight(.semibold))
          Text("Personal projects, work repositories, or both.")
            .foregroundStyle(.secondary).font(.callout)
        }
      }
      if cliMissing {
        VStack(alignment: .leading, spacing: 8) {
          Text("Install GitHub CLI and sign in, then connect.").font(.headline)
          Text("brew install gh\ngh auth login")
            .font(.system(.callout, design: .monospaced)).textSelection(.enabled)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
      } else {
        Text(
          "Hammertime will link the GitHub account that GitHub CLI is signed in to, with the same permissions. To link a different account, run gh auth login first."
        )
        .font(.callout).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
      Label("Credentials stay in Keychain.", systemImage: "lock")
        .font(.caption).foregroundStyle(.secondary)
      if let error {
        Label(error, systemImage: "exclamationmark.circle")
          .foregroundStyle(.red).font(.callout)
          .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
      }
      Divider()
      HStack {
        if connectionTask != nil {
          ProgressView().controlSize(.small)
          Text("Loading your GitHub activity…").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Button("Cancel") {
          connectionTask?.cancel()
          dismiss()
        }
        .keyboardShortcut(.cancelAction)
        Button("Connect") { connect() }
          .buttonStyle(.prominent).keyboardShortcut(.defaultAction)
          .disabled(connectionTask != nil || cliMissing)
      }
    }
    .padding(28).frame(width: 510)
    .task { await findCLI() }
    .onReceive(appBecameActive) { _ in Task { await findCLI() } }
    .onDisappear { connectionTask?.cancel() }
    .interactiveDismissDisabled(connectionTask != nil)
  }

  private func findCLI() async {
    cliMissing = await GitHubCLI.executable() == nil
  }

  private func connect() {
    error = nil
    connectionTask = Task {
      do {
        let token = try await GitHubCLI.token()
        try Task.checkCancellation()
        try await model.connect(token: token, replacing: existing?.id)
        dismiss()
      } catch is CancellationError {
      } catch {
        if !Task.isCancelled { self.error = error.localizedDescription }
      }
      connectionTask = nil
    }
  }
}
