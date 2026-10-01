import SwiftUI
import Charts

/// 統計 page: period + type toggles, donut, breakdown list, waffle.
struct StatsView: View {
    let txns: [Txn]
    let categories: [Category]

    @State private var period: StatPeriod = .month
    @State private var type: TxnType = .expense

    private func color(_ id: UUID) -> Color {
        Color(hex: categories.first { $0.id == id }?.colorHex ?? "#9CA3AF")
    }
    private func name(_ id: UUID) -> String {
        categories.first { $0.id == id }?.name ?? "—"
    }

    /// (categoryID, total) for the selected period + type, highest first.
    private var breakdown: [(categoryID: UUID, total: Decimal)] {
        let inPeriod = txnsInPeriod(txns, period: period, containing: Date())
        return categoryTotals(inPeriod, type: type)
    }

    private var total: Decimal { breakdown.reduce(0) { $0 + $1.total } }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Picker("Period", selection: $period) {
                    ForEach(StatPeriod.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Type", selection: $type) {
                    Text("Expense").tag(TxnType.expense)
                    Text("Income").tag(TxnType.income)
                }
                .pickerStyle(.segmented)

                if breakdown.isEmpty {
                    ContentUnavailableView("No data", systemImage: "chart.pie",
                        description: Text("Nothing recorded in this period."))
                        .padding(.top, 40)
                } else {
                    donut
                    breakdownList
                    waffle
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
    }

    // MARK: Donut

    private var donut: some View {
        Chart(breakdown, id: \.categoryID) { item in
            SectorMark(
                angle: .value("Total", NSDecimalNumber(decimal: item.total).doubleValue),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(color(item.categoryID))
        }
        .frame(height: 220)
        .chartBackground { _ in
            VStack {
                Text(type == .expense ? "Expense" : "Income")
                    .font(.caption).foregroundStyle(.gray)
                Text(formatMoney(total))
                    .font(.system(.title2, design: .monospaced)).bold()
                    .foregroundStyle(.white).minimumScaleFactor(0.5).lineLimit(1)
            }
        }
    }

    // MARK: Breakdown list

    private var breakdownList: some View {
        VStack(spacing: 10) {
            ForEach(breakdown, id: \.categoryID) { item in
                HStack {
                    Circle().fill(color(item.categoryID)).frame(width: 12, height: 12)
                    Text(name(item.categoryID))
                    Spacer()
                    Text(formatMoney(item.total)).foregroundStyle(.gray)
                    Text(percent(item.total)).frame(width: 52, alignment: .trailing).bold()
                }
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white)
            }
        }
    }

    private func percent(_ v: Decimal) -> String {
        guard total > 0 else { return "0%" }
        let p = NSDecimalNumber(decimal: v / total).doubleValue * 100
        return "\(Int(p.rounded()))%"
    }

    // MARK: Waffle

    private var waffle: some View {
        let counts = waffleCounts(breakdown.map { $0.total })
        // Expand into 100 colored cells by category order.
        let cellColors: [Color] = zip(breakdown, counts).flatMap { item, n in
            Array(repeating: color(item.categoryID), count: n)
        }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 10)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<100, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(i < cellColors.count ? cellColors[i] : Color.white.opacity(0.08))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}
