import AppKit
import GitHubMaxxerCore
import SwiftUI

struct ConnectionSheet: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  let existing: AccountConnection?
  @State private var label = ""
  @State private var includePrivateRepositories = true
  @State private var phase = SignInPhase.ready
  @State private var error: String?
  @State private var connectionTask: Task<Void, Never>?

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
      Form {
        TextField("Connection name", text: $label, prompt: Text("e.g. Personal or Work"))
        Toggle("Include private repositories", isOn: $includePrivateRepositories)
      }
      .disabled(phase.isBusy)
      Text(
        includePrivateRepositories
          ? "GitHub requires a permission that includes repository write access to read private activity. GitHub Maxxer only reads your data. Your organization may require approval or SSO."
          : "Browser sign in will connect your public activity and organization memberships. Private repositories will not be included."
      )
      .font(.callout).foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      if case .waiting(let authorization) = phase {
        VStack(alignment: .leading, spacing: 12) {
          Text("Enter this code on GitHub").font(.headline)
          HStack {
            Text(authorization.userCode)
              .font(.system(size: 26, weight: .medium, design: .monospaced))
              .textSelection(.enabled)
            Spacer()
            Button("Copy Code", systemImage: "doc.on.doc") {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(authorization.userCode, forType: .string)
            }
          }
          HStack {
            Text("Then approve the connection in your browser.")
              .font(.callout).foregroundStyle(.secondary)
            Spacer()
            Button("Open GitHub") { openURL(authorization.verificationURL) }
          }
        }
        .padding(16).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
      } else {
        Label(
          "Sign in securely in your browser. Credentials stay in Keychain.", systemImage: "lock"
        )
        .font(.caption).foregroundStyle(.secondary)
        if GitHubCLI.executable != nil {
          HStack {
            Text("Already connected with GitHub CLI?")
              .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Use GitHub CLI") { signIn(usingCLI: true) }
              .disabled(phase.isBusy)
              .help("Uses the existing GitHub CLI account and permissions.")
          }
        }
      }
      if let error {
        Label(error, systemImage: "exclamationmark.circle")
          .foregroundStyle(.red).font(.callout)
          .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
      }
      Divider()
      HStack {
        if phase.isBusy {
          ProgressView().controlSize(.small)
          Text(phase.status).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Button("Cancel") {
          connectionTask?.cancel()
          dismiss()
        }
        .keyboardShortcut(.cancelAction)
        if !phase.isBusy {
          Button("Sign in with GitHub") { signIn() }
            .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
        }
      }
    }
    .padding(28).frame(width: 510)
    .onAppear { label = existing?.label ?? "" }
    .onDisappear { connectionTask?.cancel() }
    .interactiveDismissDisabled(phase.isBusy)
  }

  private func signIn(usingCLI: Bool = false) {
    guard !phase.isBusy else { return }
    phase = .starting
    error = nil
    connectionTask = Task {
      do {
        let credential: String
        if usingCLI {
          credential = try await GitHubCLI.token()
        } else {
          let clientID =
            ProcessInfo.processInfo.environment["GITHUB_OAUTH_CLIENT_ID"]
            ?? Bundle.main.object(forInfoDictionaryKey: "GitHubOAuthClientID") as? String ?? ""
          let oauth = GitHubOAuth(clientID: clientID)
          let authorization = try await oauth.startAuthorization(
            includePrivateRepositories: includePrivateRepositories)
          try Task.checkCancellation()
          phase = .waiting(authorization)
          openURL(authorization.verificationURL)
          credential = try await oauth.waitForToken(authorization)
        }
        try Task.checkCancellation()
        phase = .loading
        try await model.connect(token: credential, label: label, replacing: existing?.id)
        dismiss()
      } catch is CancellationError {
      } catch {
        if !Task.isCancelled { self.error = error.localizedDescription }
      }
      phase = .ready
      connectionTask = nil
    }
  }
}

private enum SignInPhase {
  case ready, starting
  case waiting(DeviceAuthorization)
  case loading

  var isBusy: Bool {
    if case .ready = self { return false }
    return true
  }

  var status: String {
    switch self {
    case .ready: ""
    case .starting: "Starting sign in…"
    case .waiting: "Waiting for GitHub…"
    case .loading: "Loading your GitHub activity…"
    }
  }
}
