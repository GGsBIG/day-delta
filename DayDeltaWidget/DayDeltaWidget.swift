import WidgetKit
import SwiftUI

struct DayEntry: TimelineEntry {
    let date: Date
    let title: String
    let target: Date?
    let repeatsYearly: Bool
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), title: "Event", target: Date(), repeatsYearly: false)
    }

    func snapshot(for configuration: WidgetConfigIntent, in context: Context) async -> DayEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: WidgetConfigIntent, in context: Context) async -> Timeline<DayEntry> {
        let e = entry(for: configuration)
        let nextMidnight = Calendar.current.startOfDay(for: e.date.addingTimeInterval(86_400))
        return Timeline(entries: [e], policy: .after(nextMidnight))
    }

    private func entry(for c: WidgetConfigIntent) -> DayEntry {
        DayEntry(date: Date(), title: c.title, target: c.date, repeatsYearly: c.repeatsYearly)
    }
}

struct DayDeltaWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DayEntry

    private var target: Date? {
        guard let t = entry.target else { return nil }
        return entry.repeatsYearly ? nextYearlyOccurrence(of: t, from: entry.date) : t
    }

    private var delta: Int? { target.map { dayDelta(to: $0, from: entry.date) } }

    private var info: (number: String, subtitle: String)? { delta.map(deltaText) }

    var body: some View {
        switch family {
        case .accessoryInline:      inlineView
        case .accessoryCircular:    circularView
        case .accessoryRectangular: rectangularView
        default:                    homeView
        }
    }

    // MARK: Home Screen (black + monospace)

    private var homeView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.gray)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let info, let target, let delta {
                Text(info.number)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(info.subtitle)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.gray)
                Text(dateLabel(target))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.gray)
                if family == .systemMedium, delta <= 0, let m = nextMilestone(dayCount: -delta + 1) {
                    Text("next: \(m.target) · \(m.daysAway) days")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.gray)
                }
            } else {
                Text("Set a date")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.black, for: .widget)
    }

    // MARK: Lock Screen (system-tinted, minimal)

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title)
                .font(.system(.caption2, design: .monospaced))
                .lineLimit(1)
            if let info {
                Text(info.number)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .widgetAccentable()
                Text(info.subtitle)
                    .font(.system(.caption2, design: .monospaced))
            } else {
                Text("Set a date").font(.system(.caption2, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Text(info?.number ?? "—")
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .minimumScaleFactor(0.4)
                .widgetAccentable()
        }
        .containerBackground(.clear, for: .widget)
    }

    private var inlineView: some View {
        Text("\(entry.title) · \(info?.number ?? "—")")
    }
}

struct DayDeltaWidget: Widget {
    let kind = "DayDeltaWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WidgetConfigIntent.self, provider: Provider()) { entry in
            DayDeltaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("DayDelta")
        .description("Count down or up to a date.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}
