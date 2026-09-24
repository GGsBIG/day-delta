import WidgetKit
import SwiftUI

struct DayEntry: TimelineEntry {
    let date: Date
    let title: String
    let target: Date?
    let mode: CountMode
    let recurrence: Recurrence
    let iconName: String?
    let label: String?
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), title: "Event", target: Date(),
                 mode: .auto, recurrence: .none, iconName: nil, label: nil)
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
        DayEntry(date: Date(), title: c.title, target: c.date,
                 mode: c.mode, recurrence: c.recurrence, iconName: c.icon.assetName,
                 label: c.label)
    }
}

struct DayDeltaWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DayEntry

    private var target: Date? {
        guard let t = entry.target else { return nil }
        return nextOccurrence(of: t, recurrence: entry.recurrence, from: entry.date)
    }

    private var delta: Int? { target.map { dayDelta(to: $0, from: entry.date) } }

    private var info: (number: String, subtitle: String)? {
        guard let delta else { return nil }
        var d = countDisplay(delta: delta, mode: entry.mode)
        if let l = entry.label, !l.isEmpty { d.subtitle = l }
        return d
    }

    var body: some View {
        switch family {
        case .accessoryInline:      inlineView
        case .accessoryCircular:    circularView
        case .accessoryRectangular: rectangularView
        default:                    homeView
        }
    }

    private var titleRow: some View {
        HStack(spacing: 5) {
            if let iconName = entry.iconName {
                Image(iconName).renderingMode(.template).resizable().scaledToFit()
                    .frame(width: 12, height: 12)
            }
            Text(entry.title).lineLimit(1)
        }
    }

    // MARK: Home Screen (black + monospace)

    private var homeView: some View {
        VStack(alignment: .leading, spacing: 4) {
            titleRow
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.gray)
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
                if family == .systemMedium, entry.mode == .dayCounter, delta <= 0,
                   let m = nextMilestone(dayCount: -delta + 1) {
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
            titleRow.font(.system(.caption2, design: .monospaced))
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
