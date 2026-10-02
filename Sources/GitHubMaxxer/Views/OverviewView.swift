import GitHubMaxxerCore
import SwiftUI

struct OverviewView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openSettings) private var openSettings
  @Binding var filter: ActivityFilter
  let showAllPulls: () -> Void

  private var pulls: [MergedPullRequest] { model.pullRequests(for: filter) }
  private var breakdownFilters: [ActivityFilter] {
    [.all, .personal] + model.organizations.map(ActivityFilter.organization)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        VStack(alignment: .leading, spacing: 16) {
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
              Text("Merged pull requests").font(.title2.weight(.semibold))
              Text("\(model.goals.daily) PRs keeps the layoff away")
                .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit targets") { openSettings() }.buttonStyle(.link)
          }
          HStack(spacing: 14) {
            ForEach(GoalPeriod.allCases) { period in
              GoalCard(
                period: period, progress: model.progress(for: period, filter: filter),
                now: model.now, filter: filter)
            }
          }
        }
        activityBreakdown
        if filter == .all {
          ContributionGraphView()
        } else {
          Text("GitHub's account-wide contribution calendar appears in All activity.")
            .font(.caption).foregroundStyle(.secondary)
        }
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("Recent merges").font(.title3.weight(.semibold))
            Spacer()
            Button("Show all", action: showAllPulls).buttonStyle(.link)
          }
          if pulls.isEmpty {
            VStack(spacing: 8) {
              Image(systemName: "arrow.triangle.merge").font(.title2).foregroundStyle(.secondary)
              Text("No merges for \(filter.title.lowercased())").font(.headline)
              Text("Merged PRs from the last 90 days will appear here.")
                .font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 28)
          } else {
            VStack(spacing: 0) {
              ForEach(Array(pulls.prefix(5).enumerated()), id: \.element.id) {
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

  private var activityBreakdown: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Activity by organisation").font(.title3.weight(.semibold))
        Text("Merged PRs in tracked repositories, with personal work shown separately.")
          .font(.callout).foregroundStyle(.secondary)
      }
      VStack(spacing: 0) {
        HStack(spacing: 10) {
          Text("Owner").frame(maxWidth: .infinity, alignment: .leading)
          Text("Today").frame(width: 58, alignment: .trailing)
          Text("Week").frame(width: 58, alignment: .trailing)
          Text("Month").frame(width: 58, alignment: .trailing)
          Text("90 days").frame(width: 66, alignment: .trailing)
          Color.clear.frame(width: 12)
        }
        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
        .padding(.horizontal, 14).padding(.bottom, 4)
        ForEach(breakdownFilters, id: \.self) { scope in
          let today = model.progress(for: .day, filter: scope).count
          let week = model.progress(for: .week, filter: scope).count
          let month = model.progress(for: .month, filter: scope).count
          let history = model.pullRequests(for: scope).count
          Button {
            filter = scope
          } label: {
            HStack(spacing: 10) {
              Text(scope.title).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
              Text(today, format: .number)
                .frame(width: 58, alignment: .trailing)
              Text(week, format: .number)
                .frame(width: 58, alignment: .trailing)
              Text(month, format: .number)
                .frame(width: 58, alignment: .trailing)
              Text(history, format: .number)
                .frame(width: 66, alignment: .trailing)
              Image(systemName: filter == scope ? "checkmark" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 12)
            }
            .font(.callout)
            .monospacedDigit()
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(
              filter == scope ? Color.accentColor.opacity(0.1) : Color.clear,
              in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(
            "\(scope.title): \(today) today, \(week) this week, \(month) this month, \(history) in 90 days"
          )
          .accessibilityHint("Show \(scope.title.lowercased()) activity")
        }
      }
    }
    .padding(20)
    .background(.background, in: RoundedRectangle(cornerRadius: 10))
    .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.separator.opacity(0.6)) }
  }
}

private struct GoalCard: View {
  let period: GoalPeriod
  let progress: GoalProgress
  let now: Date
  let filter: ActivityFilter
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
      PeriodPullRequestsView(period: period, filter: filter)
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
  let filter: ActivityFilter
  private let rowHeight: CGFloat = 64

  var body: some View {
    let pulls = model.pullRequests(for: period, filter: filter)
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
    Link(destination: pull.url) {
      content
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      (hovering ? NSCursor.pointingHand : NSCursor.arrow).set()
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

  private var content: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "arrow.triangle.merge")
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.purple).frame(width: 24).padding(.top, 2)
      VStack(alignment: .leading, spacing: 5) {
        Text(pull.title).font(.body.weight(.medium)).foregroundStyle(.primary)
          .lineLimit(2).multilineTextAlignment(.leading)
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
  }
}
