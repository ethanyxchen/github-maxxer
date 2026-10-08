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
        SettingsButton(model: model).keyboardShortcut(",", modifiers: .command)
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

private struct SettingsButton: View {
  let model: AppModel
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button("Settings…") {
      model.destination = .settings
      openWindow(id: "main")
      NSApplication.shared.activate(ignoringOtherApps: true)
    }
    .disabled(model.isWelcoming)
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
    SettingsButton(model: model)
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
          let now = Date.now
          async let repositories = client.repositories()
          async let pulls = client.mergedPullRequests(
            from: Activity.historyInterval(endingAt: now).start, through: now)
          let profile = try await client.profile()
          print(
            "GitHub integration verified for @\(profile.login): \(try await repositories.count) repositories, \(try await pulls.count) merged PRs."
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
    let image = Bundle.main.image(forResource: "Mark")!
    image.size = NSSize(width: 18, height: 18)
    image.isTemplate = true
    return image
  }()
}
