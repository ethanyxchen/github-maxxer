import GitHubMaxxerCore
import SwiftUI

struct PullRequestsView: View {
  @Environment(AppModel.self) private var model
  @State private var search = ""
  @State private var period: GoalPeriod?

  private var pulls: [MergedPullRequest] {
    let pulls = period.map { model.pullRequests(for: $0) } ?? model.pullRequests
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
          Text("Last 90 days").tag(nil as GoalPeriod?)
          ForEach(GoalPeriod.allCases) { period in
            Text(period.title).tag(Optional(period))
          }
        }
        .pickerStyle(.segmented).frame(maxWidth: 440)
        Spacer()
        Text("\(pulls.count.formatted()) merged")
          .font(.callout).foregroundStyle(.secondary).monospacedDigit()
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
            HStack(spacing: 8) {
              Image(systemName: "arrow.triangle.merge").foregroundStyle(.purple)
              Link(pull.title, destination: pull.url)
                .foregroundStyle(.primary).lineLimit(1)
                .help(pull.title)
            }
            .padding(.vertical, 6)
          }
          .width(min: 240, ideal: 420)
          TableColumn("Repository") { pull in
            HStack(spacing: 5) {
              Text(pull.repository.nameWithOwner).lineLimit(1)
              if pull.repository.isPrivate { Image(systemName: "lock").font(.caption2) }
            }
            .foregroundStyle(.secondary)
          }
          .width(min: 130, ideal: 190)
          TableColumn("PR") { pull in
            Text("#\(pull.number)").foregroundStyle(.secondary).monospacedDigit()
          }
          .width(65)
          TableColumn("Merged") { pull in
            Text(pull.mergedAt, format: .dateTime.month(.abbreviated).day())
              .foregroundStyle(.secondary)
              .help(pull.mergedAt.formatted(date: .complete, time: .shortened))
          }
          .width(85)
        }
      }
    }
    .searchable(text: $search, prompt: "Search pull requests")
  }
}
