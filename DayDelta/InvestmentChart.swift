import SwiftUI
import Charts

/// Period options for the portfolio chart.
private enum ChartPeriod: Int, CaseIterable, Identifiable {
    case days7 = 7, days30 = 30, days90 = 90
    var id: Int { rawValue }
    var label: String { "\(rawValue) days" }
}

/// A detailed portfolio value chart: period toggle, a big scrub-aware total that
/// rolls to its value, "+X% vs previous", a solid this-period line + dashed
/// previous-period line with area fill, axes, gridlines, and touch scrubbing.
/// Values mix currencies (USD stocks + TWD stocks/gold) like the portfolio total.
struct InvestmentChartCard: View {
    let holdings: [Holding]

    @AppStorage("accentHex") private var accentHex = "#5227FF"
    @State private var period: ChartPeriod = .days30
    @State private var thisSeries: [PortfolioPoint] = []
    @State private var loading = false
    @State private var selected: Date?

    /// The one headline total: current market value of all (filtered) holdings.
    private var total: Decimal { holdings.reduce(0) { $0 + $1.marketValue } }
    private var cost: Decimal { holdings.reduce(0) { $0 + $1.cost } }
    private var gain: Decimal { total - cost }
    private var gainPct: Double { changePct(total, cost) }
    private var selectedPoint: PortfolioPoint? {
        guard let selected else { return nil }
        return thisSeries.min { abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected)) }
    }
    private var readout: Decimal { selectedPoint?.value ?? total }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            valueBlock
            periodRow
            chart.frame(height: 190)
        }
        .padding(.vertical, 8)
        .task(id: "\(period.rawValue)|\(signature)") { await reload() }
    }

    // MARK: Value block (matches the Accounts "Spend Account" style)

    private var valueBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selected == nil ? "Portfolio value" : "At point")
                .font(.system(.title3, design: .rounded)).foregroundStyle(.white.opacity(0.7))
            Text(formatMoney(readout))
                .font(.system(size: 52, weight: .thin, design: .rounded)).tracking(-1.5)
                .foregroundStyle(.white).minimumScaleFactor(0.4).lineLimit(1)
                .contentTransition(.numericText(value: (readout as NSDecimalNumber).doubleValue))
                .animation(.snappy(duration: 0.3), value: readout)
            if let p = selectedPoint {
                Text(p.date, format: .dateTime.year().month().day())
                    .font(.system(.subheadline, design: .rounded)).foregroundStyle(.white.opacity(0.7))
            } else {
                HStack(spacing: 10) {
                    Text("\(gain >= 0 ? "+" : "")\(formatMoney(gain))")
                        .font(.system(.subheadline, design: .rounded)).bold()
                        .foregroundStyle(gain >= 0 ? .green : .red)
                    Text(String(format: "%+.1f%%", gainPct))
                        .font(.system(.caption, design: .rounded)).bold().foregroundStyle(.white)
                        .padding(.vertical, 4).padding(.horizontal, 10)
                        .background(Capsule().fill(accentGradient(accentHex)))
                }
            }
        }
    }

    private var periodRow: some View {
        HStack(spacing: 2) {
            ForEach(ChartPeriod.allCases) { p in
                let on = period == p
                Button { period = p } label: {
                    Text(p.label)
                        .font(.system(.footnote, design: .rounded)).fontWeight(on ? .bold : .regular)
                        .foregroundStyle(on ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background { if on { Capsule().fill(accentGradient(accentHex)) } }
                }.buttonStyle(.plain)
            }
        }
        .padding(3).background(Capsule().fill(.white.opacity(0.06)))
    }

    // MARK: Chart

    private var chart: some View {
        Chart {
            ForEach(thisSeries) { p in
                AreaMark(x: .value("Date", p.date), y: .value("Value", p.doubleValue))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.01)],
                                                    startPoint: .top, endPoint: .bottom))
            }
            ForEach(thisSeries) { p in
                LineMark(x: .value("Date", p.date), y: .value("Value", p.doubleValue))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.white)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            if let p = selectedPoint {
                RuleMark(x: .value("Date", p.date)).foregroundStyle(.white.opacity(0.3))
                PointMark(x: .value("Date", p.date), y: .value("Value", p.doubleValue))
                    .foregroundStyle(.white).symbolSize(70)
            }
        }
        .chartXSelection(value: $selected)
        .chartYAxis {
            AxisMarks(position: .trailing) {
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.notation(.compactName))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(.white.opacity(0.5))
            }
        }
        .overlay(alignment: .topTrailing) {
            if loading { ProgressView().controlSize(.small).padding(6) }
        }
        .overlay {
            if thisSeries.isEmpty && !loading {
                ContentUnavailableView("No history", systemImage: "chart.xyaxis.line",
                    description: Text("Add holdings with a symbol to see the curve."))
            }
        }
    }

    // MARK: Data

    /// Changes whenever the holding set/quantities change (triggers a reload).
    private var signature: String {
        holdings.map { "\($0.symbol):\($0.kind):\($0.quantity)" }.sorted().joined(separator: ",")
    }

    private func reload() async {
        selected = nil
        guard !holdings.isEmpty else { thisSeries = []; return }
        loading = true
        defer { loading = false }
        let days = period.rawValue
        var history: [String: [(date: Date, close: Decimal)]] = [:]
        for s in Set(holdings.filter { $0.kind != kindGold && !$0.symbol.isEmpty }.map(\.symbol)) {
            history[s] = await QuoteService.history(for: s, days: days)
        }
        if holdings.contains(where: { $0.kind == kindGold }) {
            history["GOLD"] = await QuoteService.goldHistory(days: days)
        }
        let cur = portfolioSeries(holdings: holdings, history: history, days: days, endingAt: Date())
        // Animate the curve morph when the period changes.
        withAnimation(.easeInOut(duration: 0.5)) { thisSeries = cur }
    }
}
