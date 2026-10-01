import GitHubMaxxerCore
import SwiftUI

struct ContributionGraphView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedAccount: String?
  @State private var hoveredDay: ContributionDay?

  private var account: AccountConnection? {
    model.contributionAccounts.first { $0.profile.id == selectedAccount }
      ?? model.contributionAccounts.first
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline) {
        Text("Contribution activity").font(.title3.weight(.semibold))
        Spacer()
        if model.contributionAccounts.count > 1 {
          Picker(
            "Account",
            selection: Binding(
              get: { account?.profile.id ?? "" }, set: { selectedAccount = $0 }
            )
          ) {
            ForEach(model.contributionAccounts, id: \.profile.id) { account in
              Text("@\(account.profile.login)").tag(account.profile.id)
            }
          }
          .labelsHidden().fixedSize()
        } else if let account {
          Link("@\(account.profile.login)", destination: account.profileURL)
            .font(.callout).foregroundStyle(.secondary)
        }
      }
      if let calendar = account?.snapshot.contributions {
        graph(calendar)
        HStack(alignment: .firstTextBaseline) {
          Text(
            hoveredDay.map(dayDescription)
              ?? "\(calendar.totalContributions.formatted()) contributions in the last year"
          )
          .font(.caption).foregroundStyle(.secondary)
          Spacer()
          HStack(spacing: 4) {
            Text("Less").padding(.trailing, 3)
            ForEach(ContributionLevel.allCases, id: \.self) { level in
              RoundedRectangle(cornerRadius: 2).fill(color(level))
                .frame(width: 10, height: 10).accessibilityHidden(true)
            }
            Text("More").padding(.leading, 3)
          }
          .font(.caption2).foregroundStyle(.secondary)
        }
        Text(
          "GitHub's account-wide calendar includes commits, issues, reviews, and opened PRs. Repository tracking applies to your PR targets."
        )
        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      } else {
        Text("Your contribution calendar will appear after the first successful update.")
          .font(.callout).foregroundStyle(.secondary).padding(.vertical, 32)
      }
    }
    .padding(20)
    .background(.background, in: RoundedRectangle(cornerRadius: 10))
    .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.separator.opacity(0.6)) }
  }

  private func graph(_ calendar: ContributionCalendar) -> some View {
    let monthLabels = calendar.weeks.enumerated().map {
      monthLabel(for: $0.element, index: $0.offset, weeks: calendar.weeks)
    }
    return GeometryReader { geometry in
      let grid = ContributionGridGeometry(
        width: geometry.size.width, weekCount: calendar.weeks.count)
      Canvas { context, _ in
        for (weekday, label) in [(1, "Mon"), (3, "Wed"), (5, "Fri")] {
          context.draw(
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary),
            at: CGPoint(x: 0, y: grid.rect(week: 0, weekday: weekday).midY), anchor: .leading)
        }
        for (index, week) in calendar.weeks.enumerated() {
          context.draw(
            Text(monthLabels[index]).font(.system(size: 9)).foregroundStyle(.secondary),
            at: CGPoint(x: grid.rect(week: index, weekday: 0).minX, y: 8), anchor: .leading)
          for day in week.contributionDays {
            let rect = grid.rect(week: index, weekday: day.weekday)
            context.fill(
              Path(roundedRect: rect, cornerRadius: 2), with: .color(color(day.contributionLevel)))
            context.stroke(
              Path(roundedRect: rect.insetBy(dx: 0.25, dy: 0.25), cornerRadius: 1.75),
              with: .color(.primary.opacity(0.04)), lineWidth: 0.5)
          }
        }
      }
      .onContinuousHover { phase in
        let day: ContributionDay?
        switch phase {
        case .active(let location):
          if let cell = grid.cell(at: location) {
            day = calendar.weeks[cell.week].contributionDays.first { $0.weekday == cell.weekday }
          } else {
            day = nil
          }
        case .ended:
          day = nil
        }
        if hoveredDay?.id != day?.id { hoveredDay = day }
      }
    }
    .frame(height: 132)
    .help(hoveredDay.map(dayDescription) ?? "Hover over a day to see its contributions")
    .accessibilityRepresentation {
      HStack(spacing: 0) {
        ForEach(calendar.weeks, id: \.firstDay) { week in
          VStack(spacing: 0) {
            ForEach(0..<7) { weekday in
              if let day = week.contributionDays.first(where: { $0.weekday == weekday }) {
                Rectangle()
                  .accessibilityLabel(dayDescription(day))
              } else {
                Color.clear.accessibilityHidden(true)
              }
            }
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Daily contributions")
    }
  }

  private func monthLabel(for week: ContributionWeek, index: Int, weeks: [ContributionWeek])
    -> String
  {
    guard let date = calendarDate(week.firstDay) else { return "" }
    let current = Calendar(identifier: .gregorian).component(.month, from: date)
    if index == 0, weeks.count > 2, let next = calendarDate(weeks[2].firstDay),
      Calendar(identifier: .gregorian).component(.month, from: next) != current
    {
      return ""
    }
    if index > 0, let previous = calendarDate(weeks[index - 1].firstDay),
      Calendar(identifier: .gregorian).component(.month, from: previous) == current
    {
      return ""
    }
    return date.formatted(.dateTime.month(.abbreviated))
  }

  private func dayDescription(_ day: ContributionDay) -> String {
    let date =
      calendarDate(day.date)?.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
      ?? day.date
    return
      "\(day.contributionCount) \(day.contributionCount == 1 ? "contribution" : "contributions") on \(date)"
  }

  private func calendarDate(_ value: String) -> Date? {
    Self.dayFormatter.date(from: value)
  }

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = .autoupdatingCurrent
    return formatter
  }()

  private func color(_ level: ContributionLevel) -> Color {
    if colorScheme == .dark {
      switch level {
      case .none: Color(nsColor: .quaternaryLabelColor).opacity(0.6)
      case .first: Color(red: 0.05, green: 0.27, blue: 0.16)
      case .second: Color(red: 0.0, green: 0.43, blue: 0.2)
      case .third: Color(red: 0.15, green: 0.63, blue: 0.26)
      case .fourth: Color(red: 0.22, green: 0.83, blue: 0.33)
      }
    } else {
      switch level {
      case .none: Color(nsColor: .quaternaryLabelColor).opacity(0.35)
      case .first: Color(red: 0.61, green: 0.91, blue: 0.66)
      case .second: Color(red: 0.25, green: 0.77, blue: 0.39)
      case .third: Color(red: 0.19, green: 0.63, blue: 0.3)
      case .fourth: Color(red: 0.13, green: 0.43, blue: 0.23)
      }
    }
  }
}

extension AccountConnection {
  var profileURL: URL { URL(string: "https://github.com/\(profile.login)")! }
}
