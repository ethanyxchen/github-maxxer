import GitHubMaxxerCore
import SwiftUI

struct RecordView: View {
  @Environment(AppModel.self) private var model
  @State private var showsGitHub = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Eyebrow(showsGitHub ? "GitHub · last year" : "Last 90 days")
        Spacer()
        Picker("Calendar", selection: $showsGitHub) {
          Text("Merged PRs").tag(false)
          Text("GitHub").tag(true)
        }
        .pickerStyle(.segmented).labelsHidden().fixedSize()
      }
      if showsGitHub {
        ContributionGraphView()
      } else {
        record
      }
    }
  }

  private var record: some View {
    let days = model.dailyCounts(for: .all)
    let target = model.goals.daily
    let today = Calendar.current.startOfDay(for: model.now)
    let workdays = days.filter { !Calendar.current.isDateInWeekend($0.day) }
    return VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 3) {
        ForEach(Array(Activity.weeks(days).enumerated()), id: \.offset) { _, week in
          VStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { weekday in
              cell(week[weekday], target: target, today: today)
            }
          }
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        "\(workdays.filter { $0.count >= target }.count) of \(workdays.count) workdays reached the target in the last 90 days"
      )
      HStack(spacing: 14) {
        legend("Below", Palette.fill(count: 1, target: 2))
        legend("Reached", Palette.reached)
        legend("Over", Palette.over)
        Spacer()
        Text("\(days.reduce(0) { $0 + $1.count }) merged")
          .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.secondary)
      }
    }
  }

  @ViewBuilder
  private func cell(_ day: DailyCount?, target: Int, today: Date) -> some View {
    if let day {
      RoundedRectangle(cornerRadius: 2)
        .fill(Palette.fill(count: day.count, target: target))
        .opacity(Calendar.current.isDateInWeekend(day.day) ? 0.5 : 1)
        .frame(width: 22, height: 22)
        .overlay {
          if day.day == today {
            RoundedRectangle(cornerRadius: 3).strokeBorder(Palette.ink, lineWidth: 1.5).padding(-3)
          }
        }
        .help(
          "\(day.count) merged · \(day.day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))"
        )
    } else {
      Color.clear.frame(width: 22, height: 22)
    }
  }

  private func legend(_ title: String, _ color: Color) -> some View {
    HStack(spacing: 5) {
      RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 9, height: 9)
      Text(title.uppercased()).font(.system(size: 10, weight: .medium, design: .monospaced))
        .tracking(0.8).foregroundStyle(Palette.secondary)
    }
  }
}
