import GitHubMaxxerCore
import SwiftUI

struct OverviewView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openSettings) private var openSettings
  let showAllPulls: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        VStack(alignment: .leading, spacing: 16) {
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
              Text("Merged pull requests").font(.title2.weight(.semibold))
              Text("Your authored PRs, counted when they merge.")
                .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit targets") { openSettings() }.buttonStyle(.link)
          }
          HStack(spacing: 14) {
            ForEach(GoalPeriod.allCases) { period in
              GoalCard(period: period, progress: model.progress(for: period), now: model.now)
            }
          }
        }
        ContributionGraphView()
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("Recent merges").font(.title3.weight(.semibold))
            Spacer()
            Button("Show all", action: showAllPulls).buttonStyle(.link)
          }
          if model.pullRequests.isEmpty {
            VStack(spacing: 8) {
              Image(systemName: "arrow.triangle.merge").font(.title2).foregroundStyle(.secondary)
              Text("No merges in your tracked repositories").font(.headline)
              Text("Merged PRs from the last 90 days will appear here.")
                .font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 28)
          } else {
            VStack(spacing: 0) {
              ForEach(Array(model.pullRequests.prefix(5).enumerated()), id: \.element.id) {
                index, pull in
                if index > 0 { Divider().padding(.leading, 36) }
                PullRequestRow(pull: pull).padding(.vertical, 12)
              }
            }
          }
        }
        Text("Targets follow your Mac's time zone. Weeks start on Monday.")
          .font(.caption).foregroundStyle(.tertiary)
      }
      .padding(28)
      .frame(maxWidth: 1100)
      .frame(maxWidth: .infinity)
    }
    .background(Color(nsColor: .windowBackgroundColor))
  }
}

private struct GoalCard: View {
  let period: GoalPeriod
  let progress: GoalProgress
  let now: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text(period.title).font(.headline)
        Spacer(minLength: 0)
        if progress.isComplete {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            .help("Target reached")
        }
      }
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(progress.count, format: .number)
          .font(.system(size: 36, weight: .medium, design: .rounded))
          .foregroundStyle(progress.isComplete ? Color.green : .primary)
        Text("/ \(progress.target)")
          .font(.title3).foregroundStyle(.secondary)
      }
      .monospacedDigit()
      ProgressView(value: progress.fraction)
        .tint(.green).accessibilityLabel("\(period.title) target")
        .accessibilityValue("\(progress.count) of \(progress.target) merged pull requests")
      VStack(alignment: .leading, spacing: 4) {
        Text(progress.isComplete ? "Target reached" : "\(progress.remaining) to go")
          .font(.callout.weight(.medium))
        Text(dateLabel).font(.caption).foregroundStyle(.secondary)
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background, in: RoundedRectangle(cornerRadius: 10))
    .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.separator.opacity(0.6)) }
  }

  private var dateLabel: String {
    let interval = period.interval(containing: now)
    if period == .day { return now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }
    if period == .month { return now.formatted(.dateTime.month(.wide).year()) }
    let last = interval.end.addingTimeInterval(-1)
    return
      "\(interval.start.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
  }
}

struct PullRequestRow: View {
  let pull: MergedPullRequest

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "arrow.triangle.merge")
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.purple).frame(width: 24).padding(.top, 2)
      VStack(alignment: .leading, spacing: 5) {
        Link(destination: pull.url) {
          Text(pull.title).font(.body.weight(.medium)).foregroundStyle(.primary)
            .lineLimit(2).multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        HStack(spacing: 6) {
          Text(pull.repository.nameWithOwner)
          Text("#\(pull.number)")
          if pull.repository.isPrivate { Image(systemName: "lock").font(.caption2) }
        }
        .font(.caption).foregroundStyle(.secondary)
      }
      Spacer(minLength: 12)
      Text(pull.mergedAt, format: .relative(presentation: .named))
        .font(.caption).foregroundStyle(.secondary)
        .help(pull.mergedAt.formatted(date: .complete, time: .shortened))
        .padding(.top, 3)
    }
    .contextMenu {
      Link("Open on GitHub", destination: pull.url)
      Button("Copy link") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pull.url.absoluteString, forType: .string)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
