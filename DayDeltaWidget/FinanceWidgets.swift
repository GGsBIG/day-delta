import WidgetKit
import SwiftUI

// MARK: - Portfolio

struct PortfolioEntry: TimelineEntry {
    let date: Date
    let value: Decimal
    let gain: Decimal
}

struct PortfolioProvider: TimelineProvider {
    func placeholder(in context: Context) -> PortfolioEntry {
        PortfolioEntry(date: .now, value: 125_000, gain: 8_400)
    }
    func getSnapshot(in context: Context, completion: @escaping (PortfolioEntry) -> Void) {
        completion(entry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PortfolioEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(3600))))
    }
    private func entry() -> PortfolioEntry {
        let h = HoldingStore.load()
        let value = h.reduce(Decimal(0)) { $0 + $1.marketValue }
        let cost = h.reduce(Decimal(0)) { $0 + $1.cost }
        return PortfolioEntry(date: .now, value: value, gain: value - cost)
    }
}

struct PortfolioWidgetView: View {
    let entry: PortfolioEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Portfolio", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(formatMoney(entry.value))
                .font(.system(.title2, design: .rounded)).bold()
                .minimumScaleFactor(0.5).lineLimit(1)
            Text("\(entry.gain >= 0 ? "+" : "")\(formatMoney(entry.gain))")
                .font(.caption).foregroundStyle(entry.gain >= 0 ? .green : .red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct PortfolioWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PortfolioWidget", provider: PortfolioProvider()) { entry in
            PortfolioWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Portfolio")
        .description("Your investment portfolio value and gain.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Balance

struct BalanceEntry: TimelineEntry {
    let date: Date
    let balance: Decimal
}

struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry { BalanceEntry(date: .now, balance: 48_200) }
    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(3600))))
    }
    private func entry() -> BalanceEntry {
        let txns = TxnStore.load()
        let bal = txns.reduce(Decimal(0)) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
        return BalanceEntry(date: .now, balance: bal)
    }
}

struct BalanceWidgetView: View {
    let entry: BalanceEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Total balance", systemImage: "creditcard.fill")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(formatMoney(entry.balance))
                .font(.system(.title2, design: .rounded)).bold()
                .minimumScaleFactor(0.5).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct BalanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BalanceWidget", provider: BalanceProvider()) { entry in
            BalanceWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Balance")
        .description("Your total balance across all accounts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
