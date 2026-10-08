import AppKit
import GitHubMaxxerCore
import SwiftUI

@main
struct GitHubMaxxerApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @FocusedBinding(\.destination) private var destination
  @FocusedValue(\.searchFocus) private var searchFocus
  private var model: AppModel { delegate.model }

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
      CommandGroup(replacing: .appSettings) {
        SettingsLink().keyboardShortcut(",", modifiers: .command)
          .disabled(model.connections.isEmpty)
      }
      CommandGroup(replacing: .sidebar) {
        Button("Toggle Sidebar") {
          NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
        }
        .keyboardShortcut("s", modifiers: .command)
        .disabled(destination == nil)
        Divider()
        Button("Previous Page") { destination = destination?.step(-1, through: model.activities) }
          .keyboardShortcut("[", modifiers: [.command, .shift])
          .disabled(destination == nil)
        Button("Next Page") { destination = destination?.step(1, through: model.activities) }
          .keyboardShortcut("]", modifiers: [.command, .shift])
          .disabled(destination == nil)
        Divider()
        ForEach(Array(model.activities.prefix(9).enumerated()), id: \.element) { index, filter in
          Button(model.title(for: filter)) { destination = .activity(filter) }
            .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            .disabled(destination == nil)
        }
      }
      CommandGroup(after: .textEditing) {
        Button("Find") { searchFocus?.wrappedValue = true }
          .keyboardShortcut("f", modifiers: .command)
          .disabled(searchFocus == nil)
      }
      CommandGroup(after: .appInfo) {
        Link(
          "Hammertime on GitHub",
          destination: URL(string: "https://github.com/ethanyxchen/github-maxxer")!)
      }
    }
    Settings {
      SettingsWindow().environment(model)
        .preferredColorScheme(previewColorScheme)
    }
    .commandsRemoved()
    MenuBarExtra {
      MenuBarView().environment(model)
    } label: {
      let today = model.progress(for: .day)
      if model.isReached(.day) {
        Image(systemName: "checkmark.circle.fill")
      } else {
        Image(nsImage: .mark)
      }
      Text("\(today.count)/\(today.target)")
    }
  }
}

private struct SettingsWindow: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    SettingsView()
      .frame(width: 580, height: 580)
      .onChange(of: model.connections.isEmpty, initial: true) { _, isEmpty in
        if isEmpty { dismiss() }
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
    SettingsLink().disabled(model.connections.isEmpty)
    Divider()
    Button("Quit Hammertime") { NSApplication.shared.terminate(nil) }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = AppModel(
    preview: ProcessInfo.processInfo.arguments.contains("--preview")
      || ProcessInfo.processInfo.arguments.contains("--preview-dark"))
  private var banner: MergeBanner?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.regular)
    banner = MergeBanner(model: model)
    if ProcessInfo.processInfo.arguments.contains("--verify-github") {
      Task {
        do {
          let token = try await GitHubCLI.token()
          let client = GitHubClient(token: token)
          let profile = try await client.profile()
          let snapshot = try await client.snapshot(login: profile.login)
          print(
            "GitHub integration verified for @\(profile.login): \(snapshot.repositories.count) repositories, \(snapshot.pullRequests.count) merged PRs."
          )
          exit(0)
        } catch {
          print("GitHub verification failed: \(error.localizedDescription)")
          exit(1)
        }
      }
    } else if !ProcessInfo.processInfo.arguments.contains("--no-activate") {
      NSApplication.shared.activate(ignoringOtherApps: true)
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

extension NSImage {
  static let mark: NSImage = {
    let image = Bundle.module.image(forResource: "Mark")!
    image.size = NSSize(width: 18, height: 18)
    image.isTemplate = true
    return image
  }()
}
