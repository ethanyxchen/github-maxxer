import AppKit
import GitHubMaxxerCore
import SwiftUI

@main
struct GitHubMaxxerApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @State private var model = AppModel(
    preview: ProcessInfo.processInfo.arguments.contains("--preview")
      || ProcessInfo.processInfo.arguments.contains("--preview-dark"))

  private var previewColorScheme: ColorScheme? {
    ProcessInfo.processInfo.arguments.contains("--preview-dark") ? .dark : nil
  }

  var body: some Scene {
    Window("Hammertime", id: "main") {
      RootView().environment(model)
        .preferredColorScheme(previewColorScheme)
    }
    .defaultSize(width: 1120, height: 800)
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(after: .appInfo) {
        Link(
          "Hammertime on GitHub",
          destination: URL(string: "https://github.com/ethanyxchen/github-maxxer")!)
      }
    }
    Settings {
      SettingsView().environment(model)
        .preferredColorScheme(previewColorScheme)
        .frame(width: 580, height: 580)
    }
    MenuBarExtra("Hammertime", systemImage: "arrow.triangle.pull") {
      MenuBarView().environment(model)
    }
  }
}

private struct MenuBarView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    ForEach(GoalPeriod.allCases) { period in
      let progress = model.progress(for: period)
      Text("\(period.title): \(progress.count) / \(progress.target) PRs")
    }
    Divider()
    Button("Open Hammertime") {
      openWindow(id: "main")
      NSApplication.shared.activate(ignoringOtherApps: true)
    }
    Button("Refresh") { Task { await model.refresh() } }
      .disabled(
        model.isRefreshing || model.isConnecting || model.connections.isEmpty || model.isPreview)
    SettingsLink()
    Divider()
    Button("Quit Hammertime") { NSApplication.shared.terminate(nil) }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.regular)
    if ProcessInfo.processInfo.arguments.contains("--verify-github") {
      Task {
        do {
          let token = try await GitHubCLI.token()
          let client = GitHubClient(token: token)
          let profile = try await client.profile()
          let snapshot = try await client.snapshot(login: profile.login)
          print(
            "GitHub integration verified for @\(profile.login): \(snapshot.repositories.count) repositories, \(snapshot.pullRequests.count) merged PRs, \(snapshot.contributions.weeks.count) contribution weeks."
          )
          exit(0)
        } catch {
          print("GitHub verification failed: \(error.localizedDescription)")
          exit(1)
        }
      }
    } else {
      NSApplication.shared.activate(ignoringOtherApps: true)
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
