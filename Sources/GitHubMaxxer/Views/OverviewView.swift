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
  @State private var showingPulls = false
  @State private var isHovering = false

  var body: some View {
    Button {
      showingPulls = true
    } label: {
      content
    }
    .buttonStyle(.plain)
    .help("Show merged PRs for \(period.title.lowercased())")
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel("\(period.title): \(progress.count) merged PRs, target \(progress.target)")
    .accessibilityHint("Show merged pull requests")
    .onHover { isHovering = $0 }
    .popover(isPresented: $showingPulls, arrowEdge: .bottom) {
      PeriodPullRequestsView(period: period)
    }
  }

  private var content: some View {
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
        .tint(.green)
      VStack(alignment: .leading, spacing: 4) {
        Text(progress.isComplete ? "Target reached" : "\(progress.remaining) to go")
          .font(.callout.weight(.medium))
        HStack {
          Text(periodDateLabel(period, now: now))
          Spacer(minLength: 4)
          Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
        }
        .font(.caption).foregroundStyle(.secondary)
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background, in: RoundedRectangle(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10).strokeBorder(
        isHovering ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.6))
    }
    .contentShape(RoundedRectangle(cornerRadius: 10))
  }

}

private struct PeriodPullRequestsView: View {
  @Environment(AppModel.self) private var model
  let period: GoalPeriod
  private let rowHeight: CGFloat = 64

  var body: some View {
    let pulls = model.pullRequests(for: period)
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 5) {
          Text("\(period.title) · merged PRs").font(.headline)
          Text(periodDateLabel(period, now: model.now))
            .font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Text(pulls.count, format: .number)
          .font(.title2.weight(.medium)).monospacedDigit().foregroundStyle(.secondary)
      }
      .padding(16)
      Divider()
      if pulls.isEmpty {
        ContentUnavailableView(
          "No merged PRs", systemImage: "arrow.triangle.merge",
          description: Text("No PRs were merged in your tracked repositories during this period.")
        )
        .frame(height: 180)
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(pulls) { pull in
              PullRequestRow(pull: pull)
                .padding(.horizontal, 20)
                .frame(height: rowHeight)
                .overlay(alignment: .bottom) {
                  if pull.id != pulls.last?.id { Divider().padding(.leading, 56) }
                }
            }
          }
        }
        .frame(height: CGFloat(min(pulls.count, 5)) * rowHeight)
        .scrollIndicators(.visible)
      }
      Divider()
      Text("\(pulls.count.formatted()) merged PRs · Newest first")
        .font(.caption).foregroundStyle(.secondary)
        .padding(.horizontal, 20).padding(.vertical, 12)
    }
    .frame(width: 620)
  }
}

private func periodDateLabel(_ period: GoalPeriod, now: Date) -> String {
  let interval = period.interval(containing: now)
  if period == .day { return now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }
  if period == .month { return now.formatted(.dateTime.month(.wide).year()) }
  let last = interval.end.addingTimeInterval(-1)
  return
    "\(interval.start.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
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
        .accessibilityLabel(pull.title)
        HStack(spacing: 6) {
          Text(pull.repository.nameWithOwner).lineLimit(1).truncationMode(.middle)
            .help(pull.repository.nameWithOwner)
          Text("#\(String(pull.number))").fixedSize()
          if pull.repository.isPrivate {
            Label("Private", systemImage: "lock").fixedSize()
          } else {
            Text("Public").fixedSize()
          }
        }
        .font(.caption).foregroundStyle(.secondary)
      }
      Spacer(minLength: 12)
      VStack(alignment: .trailing, spacing: 3) {
        Text(pull.mergedAt, format: .dateTime.month(.abbreviated).day())
        Text(pull.mergedAt, format: .dateTime.hour().minute())
      }
      .font(.caption).foregroundStyle(.secondary).monospacedDigit()
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
