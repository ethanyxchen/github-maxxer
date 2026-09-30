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
    GeometryReader { geometry in
      let columns = max(calendar.weeks.count, 1)
      let size = min(
        13, max(5, (geometry.size.width - 36 - Double(columns - 1) * 3) / Double(columns)))
      HStack(alignment: .top, spacing: 7) {
        VStack(alignment: .leading, spacing: 3) {
          Color.clear.frame(height: 16)
          ForEach(0..<7) { weekday in
            Text(weekday == 1 ? "Mon" : weekday == 3 ? "Wed" : weekday == 5 ? "Fri" : "")
              .font(.system(size: 9)).foregroundStyle(.secondary)
              .frame(width: 27, height: size, alignment: .leading)
          }
        }
        HStack(alignment: .top, spacing: 3) {
          ForEach(Array(calendar.weeks.enumerated()), id: \.offset) { index, week in
            VStack(spacing: 3) {
              Text(monthLabel(for: week, index: index, weeks: calendar.weeks))
                .font(.system(size: 9)).foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: size, height: 16, alignment: .leading)
              ForEach(0..<7) { weekday in
                if let day = week.contributionDays.first(where: { $0.weekday == weekday }) {
                  RoundedRectangle(cornerRadius: 2)
                    .fill(color(day.contributionLevel))
                    .frame(width: size, height: size)
                    .overlay {
                      RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(.primary.opacity(0.04), lineWidth: 0.5)
                    }
                    .help(dayDescription(day))
                    .onHover { inside in
                      if inside {
                        hoveredDay = day
                      } else if hoveredDay?.id == day.id {
                        hoveredDay = nil
                      }
                    }
                    .accessibilityLabel(dayDescription(day))
                } else {
                  Color.clear.frame(width: size, height: size).accessibilityHidden(true)
                }
              }
            }
            .frame(width: size)
          }
        }
      }
    }
    .frame(height: 132)
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
