import WidgetKit
import SwiftUI

struct DayEntry: TimelineEntry {
    let date: Date
    let title: String
    let target: Date?
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), title: "Event", target: Date())
    }

    func snapshot(for configuration: WidgetConfigIntent, in context: Context) async -> DayEntry {
        DayEntry(date: Date(), title: configuration.title, target: configuration.date)
    }

    func timeline(for configuration: WidgetConfigIntent, in context: Context) async -> Timeline<DayEntry> {
        let now = Date()
        let entry = DayEntry(date: now, title: configuration.title, target: configuration.date)
        let nextMidnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }
}

struct DayDeltaWidgetEntryView: View {
    var entry: DayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.gray)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let target = entry.target {
                let t = deltaText(dayDelta(to: target, from: entry.date))
                Text(t.number)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(t.subtitle)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.gray)
            } else {
                Text("Set a date")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.black, for: .widget)
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
