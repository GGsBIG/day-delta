import SwiftUI
import Charts

/// Stats tab: period + type toggles, donut, breakdown list. Loads its own data.
struct StatsView: View {
    @State private var txns: [Txn] = TxnStore.load()
    @State private var categories: [Category] = CategoryStore.load()

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
        NavigationStack {
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
                            .transition(.opacity)
                    } else {
                        donut
                        breakdownList
                    }
                }
                .padding()
                // One smooth animation drives the whole panel — donut arcs morph and
                // rows fade/slide — on any period/type change.
                .animation(.smooth(duration: 0.45), value: period)
                .animation(.smooth(duration: 0.45), value: type)
                .sensoryFeedback(.selection, trigger: period)
                .sensoryFeedback(.selection, trigger: type)
            }
            .scrollContentBackground(.hidden)
            .background(.clear)
            .navigationTitle("Stats")
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .onAppear {
            txns = TxnStore.load()
            categories = CategoryStore.load()
        }
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
                    .font(.system(.title2, design: .rounded)).bold()
                    .foregroundStyle(.white).minimumScaleFactor(0.5).lineLimit(1)
                    .contentTransition(.numericText())
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
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
    }

    private func percent(_ v: Decimal) -> String {
        guard total > 0 else { return "0%" }
        let p = NSDecimalNumber(decimal: v / total).doubleValue * 100
        return "\(Int(p.rounded()))%"
    }
}
