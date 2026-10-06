import GitHubMaxxerCore
import SwiftUI

struct ActivityView: View {
  @Environment(AppModel.self) private var model
  let filter: ActivityFilter
  let title: String
  @State private var search = ""
  @State private var page = 0

  private var interval: DateInterval { Activity.page(page, endingAt: model.now) }

  private func days(in pulls: [MergedPullRequest]) -> [(day: Date, pulls: [MergedPullRequest])] {
    let interval = interval
    let pulls = pulls.filter { pull in
      guard !search.isEmpty else {
        return pull.mergedAt >= interval.start && pull.mergedAt < interval.end
      }
      return pull.title.localizedCaseInsensitiveContains(search)
        || pull.repository.nameWithOwner.localizedCaseInsensitiveContains(search)
        || "#\(pull.number)".contains(search)
    }
    return Dictionary(grouping: pulls) { Calendar.current.startOfDay(for: $0.mergedAt) }
      .sorted { $0.key > $1.key }
      .map { (day: $0.key, pulls: $0.value) }
  }

  var body: some View {
    let pulls = model.pullRequests(for: filter)
    return ScrollViewReader { proxy in
      ScrollView {
        VStack(spacing: 0) {
          PageTitle(title).padding(.top, 28)
          progress(pulls).padding(.top, 24).padding(.bottom, 32)
          log(days(in: pulls)).padding(.vertical, 20).id("log")
          if search.isEmpty { pager.padding(.bottom, 28) }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: 960)
        .frame(maxWidth: .infinity)
      }
      .onChange(of: page) { proxy.scrollTo("log", anchor: .top) }
    }
    .background(Palette.panel)
    .foregroundStyle(Palette.ink)
    .searchable(text: $search, placement: .toolbar, prompt: "Search merges")
    .findable()
  }

  private func progress(_ pulls: [MergedPullRequest]) -> some View {
    HStack(alignment: .top, spacing: 48) {
      today(progress(.day, in: pulls), shares: shares(.day, in: pulls)).frame(
        maxWidth: .infinity, alignment: .leading)
      VStack(alignment: .leading, spacing: 28) {
        ForEach([GoalPeriod.week, .month]) { period in
          self.period(period, progress(period, in: pulls), shares: shares(period, in: pulls))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func progress(_ period: GoalPeriod, in pulls: [MergedPullRequest]) -> GoalProgress {
    GoalProgress(
      count: period.count(in: pulls, now: model.now), target: model.goals(for: filter)[period])
  }

  private func shares(_ period: GoalPeriod, in pulls: [MergedPullRequest]) -> [MeterShare] {
    guard filter == .all else { return [] }
    let workspaces = model.workspaces.map { workspace in
      MeterShare(
        id: workspace, title: model.title(for: workspace),
        count: period.count(in: model.pullRequests(for: workspace), now: model.now),
        target: model.goals(for: workspace)[period],
        color: Palette.colour(model.colour(for: workspace)))
    }
    let other = period.count(in: pulls, now: model.now) - workspaces.map(\.count).reduce(0, +)
    return
      (workspaces
      + [MeterShare(id: "other", title: "Other", count: other, target: 0, color: Palette.secondary)])
      .filter { $0.count > 0 || $0.target > 0 }
  }

  private func pace(_ period: GoalPeriod, _ progress: GoalProgress) -> Int? {
    period == .day || progress.isComplete || progress.target == 0
      ? nil : period.pace(target: progress.target, now: model.now)
  }

  private func today(_ progress: GoalProgress, shares: [MeterShare]) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Eyebrow("Today")
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(padded(progress.count)).font(.readout(64))
        Text("/ \(padded(progress.target))").font(.readout(22)).foregroundStyle(Palette.secondary)
      }
      SegmentMeter(
        count: progress.count, target: progress.target,
        tint: Palette.colour(model.colour(for: filter)), shares: shares)
      HStack(spacing: 8) {
        Lamp(isOn: progress.isComplete)
        Text(status(progress)).font(.system(size: 12, design: .monospaced))
          .foregroundStyle(Palette.secondary)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Today: \(progress.count) merged PRs, target \(progress.target). \(status(progress))\(breakdown(shares))"
    )
  }

  private func period(_ period: GoalPeriod, _ progress: GoalProgress, shares: [MeterShare])
    -> some View
  {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(period.title).fontWeight(.semibold)
        Text(periodDateLabel(period, now: model.now)).font(.caption)
          .foregroundStyle(Palette.secondary)
        Spacer()
        Text("\(padded(progress.count)) / \(padded(progress.target))").font(.readout(14))
      }
      SegmentMeter(
        count: progress.count, target: progress.target, pace: pace(period, progress),
        tint: Palette.colour(model.colour(for: filter)), shares: shares, height: 14)
      Text(note(period, progress)).font(.system(size: 11, design: .monospaced))
        .foregroundStyle(Palette.secondary).padding(.top, 4)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(period.title): \(progress.count) merged PRs, target \(progress.target). \(note(period, progress))\(breakdown(shares))"
    )
  }

  @ViewBuilder
  private func log(_ days: [(day: Date, pulls: [MergedPullRequest])]) -> some View {
    if days.isEmpty {
      if search.isEmpty {
        ContentUnavailableView(
          "No merges in these 7 days", systemImage: "arrow.triangle.merge",
          description: Text("PRs you author appear here after they merge in a tracked repository."))
      } else {
        ContentUnavailableView.search(text: search)
      }
    } else {
      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(days, id: \.day) { entry in
          Section {
            ForEach(entry.pulls) { pull in
              PullRequestRow(pull: pull, landing: landing(pull)).padding(.vertical, 9)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
          } header: {
            dayHeader(entry.day, count: entry.pulls.count)
          }
        }
      }
      .animation(.spring(duration: 0.5, bounce: 0.3), value: model.now)
    }
  }

  private func landing(_ pull: MergedPullRequest) -> Landing? {
    model.landing.flatMap { $0.pullRequests.contains(pull.id) ? $0 : nil }
  }

  private var pager: some View {
    let last = interval.end.addingTimeInterval(-1)
    let range =
      "\(interval.start.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))"
    return HStack {
      Button {
        page += 1
      } label: {
        Label("Older", systemImage: "chevron.left")
      }
      .disabled(page == Activity.pageCount - 1)
      .opacity(page == Activity.pageCount - 1 ? 0.3 : 1)
      Spacer()
      Text(page == 0 ? "Last 7 days · \(range)" : range).font(.readout(12))
        .foregroundStyle(Palette.secondary)
      Spacer()
      Button {
        page -= 1
      } label: {
        HStack(spacing: 4) {
          Text("Newer")
          Image(systemName: "chevron.right")
        }
      }
      .disabled(page == 0)
      .opacity(page == 0 ? 0.3 : 1)
    }
    .buttonStyle(.borderless)
    .font(.system(size: 12, weight: .medium, design: .monospaced))
  }

  private func dayHeader(_ day: Date, count: Int) -> some View {
    let target = model.goals(for: filter).daily
    return HStack {
      Eyebrow(dayName(day))
      Spacer()
      Text("\(padded(count)) / \(padded(target))").font(.readout(11))
        .foregroundStyle(target > 0 && count >= target ? Palette.reached : Palette.secondary)
    }
    .padding(.top, 18).padding(.bottom, 8)
    .overlay(alignment: .bottom) { Rule() }
  }

  private func dayName(_ day: Date) -> String {
    if Calendar.current.isDateInToday(day) { return "Today" }
    if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
    return day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
  }

  private func breakdown(_ shares: [MeterShare]) -> String {
    shares.map { ". \($0.title): \($0.count) of \($0.target)" }.joined()
  }

  private func status(_ progress: GoalProgress) -> String {
    if progress.target == 0 { return "No target" }
    guard progress.isComplete else { return "\(progress.remaining) to go" }
    let over = progress.count - progress.target
    return over > 0 ? "Target reached · \(over) over" : "Target reached"
  }

  private func note(_ period: GoalPeriod, _ progress: GoalProgress) -> String {
    if progress.target == 0 { return "No target" }
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

private func periodDateLabel(_ period: GoalPeriod, now: Date) -> String {
  guard period == .week else { return now.formatted(.dateTime.month(.wide).year()) }
  let interval = period.interval(containing: now)
  let last = interval.end.addingTimeInterval(-1)
  return
    "\(interval.start.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
}

private struct PullRequestRow: View {
  let pull: MergedPullRequest
  let landing: Landing?

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

  private static let titleFont = NSFont.systemFont(ofSize: 13, weight: .medium)

  private var content: some View {
    HStack(alignment: landing == nil ? .firstTextBaseline : .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(pull.title).font(Font(Self.titleFont)).foregroundStyle(Palette.ink).lineLimit(1)
          .help(pull.title)
        Text("#\(String(pull.number)) · \(pull.repository.nameWithOwner)")
          .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 12)
      HStack(spacing: 12) {
        if let landing { MergedStamp(landing: landing) }
        Text(pull.mergedAt, format: .dateTime.hour().minute())
          .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.secondary)
          .help(pull.mergedAt.formatted(date: .complete, time: .shortened))
      }
      .padding(.top, landing == nil ? 0 : Self.titleFont.ascender - Self.titleFont.capHeight)
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}
