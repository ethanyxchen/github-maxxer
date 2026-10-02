import GitHubMaxxerCore
import SwiftUI

struct PullRequestsView: View {
  @Environment(AppModel.self) private var model
  let filter: ActivityFilter
  @State private var search = ""
  @State private var period: GoalPeriod?

  private var pulls: [MergedPullRequest] {
    let pulls =
      period.map { model.pullRequests(for: $0, filter: filter) }
      ?? model.pullRequests(for: filter)
    return pulls.filter { pull in
      search.isEmpty || pull.title.localizedCaseInsensitiveContains(search)
        || pull.repository.nameWithOwner.localizedCaseInsensitiveContains(search)
        || "#\(pull.number)".contains(search)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Picker("Period", selection: $period) {
          Text("90 days").tag(nil as GoalPeriod?)
          ForEach(GoalPeriod.allCases) { period in
            Text(period.title).tag(Optional(period))
          }
        }
        .pickerStyle(.segmented).frame(maxWidth: 440)
        Spacer()
        Eyebrow("\(pulls.count.formatted()) merged")
      }
      .padding(20)
      if pulls.isEmpty {
        ContentUnavailableView {
          Label(
            search.isEmpty ? "No merged pull requests" : "No matching pull requests",
            systemImage: "arrow.triangle.merge")
        } description: {
          Text(
            search.isEmpty
              ? "PRs you author will appear here after they merge in a tracked repository."
              : "Try another title, repository, or PR number.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        Table(pulls) {
          TableColumn("Pull request") { pull in
            Link(pull.title, destination: pull.url)
              .foregroundStyle(Palette.ink).lineLimit(1)
              .help(pull.title)
              .padding(.vertical, 6)
          }
          .width(min: 240, ideal: 420)
          TableColumn("Repository") { pull in
            Text(pull.repository.nameWithOwner + (pull.repository.isPrivate ? " · private" : ""))
              .font(.system(size: 11, design: .monospaced)).lineLimit(1)
              .foregroundStyle(Palette.secondary)
          }
          .width(min: 130, ideal: 190)
          TableColumn("PR") { pull in
            Text("#\(String(pull.number))").font(.system(size: 11, design: .monospaced))
              .foregroundStyle(Palette.secondary)
          }
          .width(65)
          TableColumn("Merged") { pull in
            Text(pull.mergedAt, format: .dateTime.month(.abbreviated).day())
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(Palette.secondary)
              .help(pull.mergedAt.formatted(date: .complete, time: .shortened))
          }
          .width(85)
        }
      }
    }
    .searchable(text: $search, prompt: "Search pull requests")
  }
}
