import SwiftUI
import Charts

/// Period options for the portfolio chart.
/// A detailed portfolio value chart over a fixed 90-day window: a big scrub-aware
/// total that rolls to its value, gain amount + %, an area line, axes, gridlines,
/// and touch scrubbing.
/// Values mix currencies (USD stocks + TWD stocks/gold) like the portfolio total.
struct InvestmentChartCard: View {
    let holdings: [Holding]
    var displayUSD = false   // US Stocks filter → show USD; else convert to TWD
    var fx: Decimal = 32     // USD→TWD
    var currencyCode = "TWD"

    private let days = 90   // fixed 90-day window (no user toggle)
    @AppStorage("accentHex") private var accentHex = "#5227FF"
    @State private var thisSeries: [PortfolioPoint] = []
    @State private var loading = false
    @State private var selected: Date?

    private func disp(_ mv: Decimal, _ kind: String) -> Decimal {
        value(mv, kind: kind, displayUSD: displayUSD, fx: fx)
    }
    /// The one headline total: current market value of all (filtered) holdings.
    private var total: Decimal { holdings.reduce(0) { $0 + disp($1.marketValue, $1.kind) } }
    private var cost: Decimal { holdings.reduce(0) { $0 + disp($1.cost, $1.kind) } }
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
            // Only draw the Chart with real data — an empty series gives Charts a
            // degenerate domain and floods "Invalid frame dimension" warnings.
            Group {
                if thisSeries.isEmpty {
                    placeholder
                } else {
                    chart
                }
            }
            .frame(height: 190)
        }
        .padding(.vertical, 8)
        .task(id: "\(signature)|\(displayUSD)|\(fx)") { await reload() }
    }

    private var placeholder: some View {
        ZStack {
            if loading { ProgressView() }
            else {
                ContentUnavailableView("No history", systemImage: "chart.xyaxis.line",
                    description: Text("Add holdings with a symbol to see the curve."))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Value block (matches the Accounts "Spend Account" style)

    private var valueBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selected == nil ? "Portfolio value" : "At point")
                .font(.system(.title3, design: .rounded)).foregroundStyle(.white.opacity(0.7))
            Text(formatMoney(readout, code: currencyCode))
                .font(.system(size: 60, weight: .thin, design: .rounded)).tracking(0.5)
                .foregroundStyle(.white).minimumScaleFactor(0.4).lineLimit(1)
                .contentTransition(.numericText(value: (readout as NSDecimalNumber).doubleValue))
                .animation(Motion.quick, value: readout)
            if let p = selectedPoint {
                Text(p.date, format: .dateTime.year().month().day())
                    .font(.system(.subheadline, design: .rounded)).foregroundStyle(.white.opacity(0.7))
            } else {
                HStack(spacing: 10) {
                    Text("\(gain >= 0 ? "+" : "")\(formatMoney(gain, code: currencyCode))")
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
        var history: [String: [(date: Date, close: Decimal)]] = [:]
        for s in Set(holdings.filter { $0.kind != kindGold && !$0.symbol.isEmpty }.map(\.symbol)) {
            history[s] = await QuoteService.history(for: s, days: days)
        }
        if holdings.contains(where: { $0.kind == kindGold }) {
            history["GOLD"] = await QuoteService.goldHistory(days: days)
        }
        // In TWD view, scale US-stock histories by fx so the whole curve is in TWD.
        if !displayUSD {
            let usSymbols = Set(holdings.filter { $0.kind == kindUSStocks }.map(\.symbol))
            for s in usSymbols where history[s] != nil {
                history[s] = history[s]!.map { ($0.date, $0.close * fx) }
            }
        }
        let cur = portfolioSeries(holdings: holdings, history: history, days: days, endingAt: Date())
        // Animate the curve morph when data changes.
        withAnimation(Motion.smooth) { thisSeries = cur }
    }
}
