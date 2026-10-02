import GitHubMaxxerCore
import SwiftUI

struct OverviewView: View {
  @Environment(AppModel.self) private var model
  @Binding var filter: ActivityFilter
  let showAllPulls: () -> Void

  private var owners: [ActivityFilter] {
    [.all, .personal] + model.organizations.map(ActivityFilter.organization)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        HStack(alignment: .top, spacing: 0) {
          today.padding(24).frame(maxWidth: .infinity, alignment: .leading)
          Rule(vertical: true)
          VStack(alignment: .leading, spacing: 28) {
            period(.week)
            period(.month)
          }
          .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
        Rule()
        HStack(alignment: .top, spacing: 0) {
          RecordView(filter: filter).padding(24).frame(maxWidth: .infinity, alignment: .leading)
          Rule(vertical: true)
          recentMerges.padding(.vertical, 20).frame(width: 400)
        }
        if !model.organizations.isEmpty {
          Rule()
          ownerTable.padding(24)
        }
      }
      .background(Palette.panel)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.rule) }
      .padding(24)
      .frame(maxWidth: 1100)
      .frame(maxWidth: .infinity)
    }
    .background(Palette.background)
    .foregroundStyle(Palette.ink)
  }

  private var today: some View {
    let progress = model.progress(for: .day, filter: filter)
    return PeriodLink(period: .day, filter: filter) {
      VStack(alignment: .leading, spacing: 16) {
        Eyebrow("Today · merged PRs")
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          Text(padded(progress.count)).font(.readout(64))
          Text("/ \(padded(progress.target))").font(.readout(22)).foregroundStyle(Palette.secondary)
        }
        SegmentMeter(
          count: progress.count, target: progress.target,
          scale: max(progress.target * 2, progress.count))
        HStack(spacing: 8) {
          Lamp(isOn: progress.isComplete)
          Text(status(progress)).font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Palette.secondary)
        }
      }
    }
    .accessibilityLabel("Today: \(progress.count) merged PRs, target \(progress.target)")
  }

  private func period(_ period: GoalPeriod) -> some View {
    let progress = model.progress(for: period, filter: filter)
    let scale = period == .week ? progress.target + progress.target / 3 : progress.target
    return PeriodLink(period: period, filter: filter) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .firstTextBaseline) {
          Text(period.title).fontWeight(.semibold)
          Text(periodDateLabel(period, now: model.now)).font(.caption)
            .foregroundStyle(Palette.secondary)
          Spacer()
          Text("\(padded(progress.count)) / \(padded(progress.target))").font(.readout(14))
        }
        SegmentMeter(
          count: progress.count, target: progress.target, scale: max(scale, progress.count),
          pace: progress.isComplete ? nil : period.pace(target: progress.target, now: model.now),
          height: 14)
        Text(note(period, progress)).font(.system(size: 11, design: .monospaced))
          .foregroundStyle(Palette.secondary).padding(.top, 4)
      }
    }
    .accessibilityLabel(
      "\(period.title): \(progress.count) merged PRs, target \(progress.target). \(note(period, progress))"
    )
  }

  private var recentMerges: some View {
    let pulls = model.pullRequests(for: filter).prefix(6)
    return VStack(alignment: .leading, spacing: 0) {
      HStack {
        Eyebrow("Recent merges")
        Spacer()
        Button("Show all", action: showAllPulls).buttonStyle(.link).font(.caption)
      }
      .padding(.horizontal, 20).padding(.bottom, 8)
      if pulls.isEmpty {
        Text("No merges in the last 90 days").font(.callout).foregroundStyle(Palette.secondary)
          .padding(20)
      }
      ForEach(pulls) { pull in
        Rule()
        PullRequestRow(pull: pull).padding(.horizontal, 20).padding(.vertical, 10)
      }
    }
  }

  private var ownerTable: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Eyebrow("By owner").frame(maxWidth: .infinity, alignment: .leading)
        ForEach(GoalPeriod.allCases) { period in
          Eyebrow(period.title).frame(width: 90, alignment: .trailing)
        }
      }
      .padding(.horizontal, 10).padding(.bottom, 4)
      ForEach(owners, id: \.self) { owner in
        let counts = GoalPeriod.allCases.map { model.progress(for: $0, filter: owner).count }
        Button {
          filter = owner
        } label: {
          HStack {
            Text(owner.title).fontWeight(filter == owner ? .semibold : .regular)
              .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(counts.indices, id: \.self) { index in
              Text(padded(counts[index])).font(.readout(12)).frame(width: 90, alignment: .trailing)
            }
          }
          .padding(.horizontal, 10).frame(height: 32)
          .background(
            filter == owner ? Palette.empty : .clear, in: RoundedRectangle(cornerRadius: 4)
          )
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
          "\(owner.title): \(counts[0]) today, \(counts[1]) this week, \(counts[2]) this month"
        )
        .accessibilityAddTraits(filter == owner ? .isSelected : [])
      }
    }
  }

  private func status(_ progress: GoalProgress) -> String {
    guard progress.isComplete else { return "\(progress.remaining) to go" }
    let over = progress.count - progress.target
    return over > 0 ? "Target reached · \(over) over" : "Target reached"
  }

  private func note(_ period: GoalPeriod, _ progress: GoalProgress) -> String {
    if progress.isComplete { return "Target reached" }
    let delta = progress.count - period.pace(target: progress.target, now: model.now)
    if delta > 0 { return "\(delta) ahead of pace" }
    if delta < 0 { return "\(-delta) behind pace" }
    return "On pace"
  }
}

private func padded(_ value: Int) -> String {
  value < 10 ? "0\(value)" : String(value)
}

private struct PeriodLink<Label: View>: View {
  let period: GoalPeriod
  let filter: ActivityFilter
  @ViewBuilder let label: Label
  @State private var showingPulls = false

  var body: some View {
    Button {
      showingPulls = true
    } label: {
      label.contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("Show merged PRs for \(period.title.lowercased())")
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits(.isButton)
    .accessibilityHint("Show merged pull requests")
    .popover(isPresented: $showingPulls, arrowEdge: .bottom) {
      PeriodPullRequestsView(period: period, filter: filter)
    }
  }
}

private struct PeriodPullRequestsView: View {
  @Environment(AppModel.self) private var model
  let period: GoalPeriod
  let filter: ActivityFilter
  private let rowHeight: CGFloat = 54

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
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(pull.title).fontWeight(.medium).foregroundStyle(Palette.ink).lineLimit(1)
          .help(pull.title)
        Text("#\(String(pull.number)) · \(pull.repository.nameWithOwner)")
          .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 12)
      Text(pull.mergedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
        .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.secondary)
        .help(pull.mergedAt.formatted(date: .complete, time: .shortened))
    }
  }
}
