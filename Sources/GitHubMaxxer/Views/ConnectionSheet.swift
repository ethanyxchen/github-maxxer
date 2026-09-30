import SwiftUI

struct ConnectionSheet: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  let existing: AccountConnection?
  @State private var label = ""
  @State private var token = ""
  @State private var isConnecting = false
  @State private var error: String?
  @State private var connectionTask: Task<Void, Never>?
  @FocusState private var tokenFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 12) {
        Image(systemName: "person.crop.circle.badge.checkmark")
          .font(.system(size: 32, weight: .light)).foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 5) {
          Text(existing == nil ? "Connect GitHub" : "Reconnect @\(existing!.profile.login)")
            .font(.title2.weight(.semibold))
          Text("Personal projects, work repositories, or both.")
            .foregroundStyle(.secondary).font(.callout)
        }
      }
      Form {
        TextField("Connection name", text: $label, prompt: Text("e.g. Personal or Work"))
        SecureField("Access token", text: $token, prompt: Text("GitHub personal access token"))
          .focused($tokenFocused)
          .onSubmit { if !token.isEmpty && !isConnecting { connect(usingCLI: false) } }
      }
      .disabled(isConnecting)
      HStack {
        Link(
          "Create a token on GitHub",
          destination: URL(string: "https://github.com/settings/tokens")!)
        Spacer()
        Label("Saved in Keychain", systemImage: "lock").foregroundStyle(.secondary)
      }
      .font(.caption)
      DisclosureGroup("Token permissions") {
        Text(
          "Use a token with access to the repositories you want to track. For a classic token, use repo, read:user, and read:org. Authorize the token for SSO if your work organization requires it. A fine-grained token needs read access to pull requests; add a separate connection for each resource owner."
        )
        .font(.callout).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
      }
      if GitHubCLI.executable != nil {
        Divider()
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Already signed in with GitHub CLI?").font(.callout.weight(.medium))
            Text("Use the account currently signed in to github.com.")
              .font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
          Button("Use GitHub CLI") { connect(usingCLI: true) }
            .disabled(isConnecting)
        }
      }
      if let error {
        Label(error, systemImage: "exclamationmark.circle")
          .foregroundStyle(.red).font(.callout)
          .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
      }
      HStack {
        if isConnecting {
          ProgressView().controlSize(.small)
          Text("Loading your GitHub activity…").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Button("Cancel") {
          connectionTask?.cancel()
          dismiss()
        }
        .keyboardShortcut(.cancelAction)
        Button(existing == nil ? "Connect" : "Reconnect") { connect(usingCLI: false) }
          .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
          .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)
      }
    }
    .padding(28).frame(width: 510)
    .onAppear {
      label = existing?.label ?? ""
      tokenFocused = true
    }
    .onDisappear {
      connectionTask?.cancel()
      token = ""
    }
    .interactiveDismissDisabled(isConnecting)
  }

  private func connect(usingCLI: Bool) {
    isConnecting = true
    error = nil
    connectionTask = Task {
      do {
        let credential = try await usingCLI ? GitHubCLI.token() : token
        try Task.checkCancellation()
        try await model.connect(token: credential, label: label, replacing: existing?.id)
        token = ""
        dismiss()
      } catch is CancellationError {
      } catch {
        if !Task.isCancelled { self.error = error.localizedDescription }
      }
      isConnecting = false
    }
  }
}
