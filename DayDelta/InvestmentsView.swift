import SwiftUI

/// Portfolio overview: total market value, cost, and unrealized P/L, plus a list
/// of holdings. Prices are entered by hand. Opened as a sheet from Accounts.
struct InvestmentsView: View {
    @State private var holdings: [Holding] = HoldingStore.load()
    @State private var editing: Holding?
    @Environment(\.dismiss) private var dismiss

    private var totalValue: Decimal { holdings.reduce(0) { $0 + $1.marketValue } }
    private var totalCost: Decimal { holdings.reduce(0) { $0 + $1.cost } }
    private var totalGain: Decimal { totalValue - totalCost }
    private var gainPct: Double {
        let c = (totalCost as NSDecimalNumber).doubleValue
        guard c > 0 else { return 0 }
        return (totalGain as NSDecimalNumber).doubleValue / c * 100
    }

    var body: some View {
        NavigationStack {
            Group {
                if holdings.isEmpty {
                    ContentUnavailableView("No investments", systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Tap + to add a holding."))
                } else {
                    List {
                        Section { summary.listRowBackground(Color.clear) }
                        Section("Holdings") {
                            ForEach(holdings) { h in
                                Button { editing = h } label: { row(h) }.buttonStyle(.plain)
                            }
                            .onDelete { offsets in
                                holdings.remove(atOffsets: offsets); HoldingStore.save(holdings)
                            }
                            .listRowBackground(Color.white.opacity(0.06))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(GrainientBackground().ignoresSafeArea())
            .navigationTitle("Investments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { editing = Holding(kind: investmentKinds[0].name, name: "",
                                               quantity: 0, costPerUnit: 0, currentPrice: 0) } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editing) { h in
                HoldingEditSheet(holding: h) { saved in
                    if let i = holdings.firstIndex(where: { $0.id == saved.id }) { holdings[i] = saved }
                    else { holdings.append(saved) }
                    HoldingStore.save(holdings)
                    editing = nil
                }
            }
        }
        .preferredColorScheme(.dark).tint(.white)
        .onAppear { holdings = HoldingStore.load() }
    }

    // MARK: Summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Portfolio value").font(.caption).foregroundStyle(.white.opacity(0.6))
            Text(formatMoney(totalValue))
                .font(.system(size: 40, weight: .thin, design: .rounded)).tracking(-1)
                .foregroundStyle(.white).minimumScaleFactor(0.4).lineLimit(1)
            HStack(spacing: 12) {
                Text("Cost \(formatMoney(totalCost))").font(.caption).foregroundStyle(.white.opacity(0.6))
                Text("\(totalGain >= 0 ? "+" : "")\(formatMoney(totalGain)) (\(String(format: "%+.1f%%", gainPct)))")
                    .font(.system(.subheadline, design: .rounded)).bold()
                    .foregroundStyle(totalGain >= 0 ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: Row

    private func row(_ h: Holding) -> some View {
        HStack(spacing: 12) {
            Image(systemName: kindIcon(h.kind)).font(.system(size: 20))
                .foregroundStyle(Color(hex: kindColorHex(h.kind))).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(h.name.isEmpty ? h.kind : h.name).foregroundStyle(.white)
                Text("\(decimal(h.quantity)) · \(h.kind)").font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatMoney(h.marketValue)).foregroundStyle(.white)
                Text("\(h.gain >= 0 ? "+" : "")\(formatMoney(h.gain))")
                    .font(.caption).foregroundStyle(h.gain >= 0 ? .green : .red)
            }
        }
        .font(.system(.body, design: .rounded))
    }
}

/// Add / edit one holding. Decimal fields use the decimal keypad.
private struct HoldingEditSheet: View {
    @State var holding: Holding
    let onSave: (Holding) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var qty: String
    @State private var cost: String
    @State private var price: String

    init(holding: Holding, onSave: @escaping (Holding) -> Void) {
        _holding = State(initialValue: holding)
        self.onSave = onSave
        _qty = State(initialValue: holding.quantity == 0 ? "" : "\(holding.quantity)")
        _cost = State(initialValue: holding.costPerUnit == 0 ? "" : "\(holding.costPerUnit)")
        _price = State(initialValue: holding.currentPrice == 0 ? "" : "\(holding.currentPrice)")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Instrument") {
                    Picker("Kind", selection: $holding.kind) {
                        ForEach(investmentKinds, id: \.name) { k in
                            Label(k.name, systemImage: k.icon).tag(k.name)
                        }
                    }
                    TextField("Name (e.g. AAPL)", text: $holding.name)
                }
                Section("Position") {
                    field("Quantity", $qty)
                    field("Cost per unit", $cost)
                    field("Current price", $price)
                    DatePicker("Date", selection: $holding.date, displayedComponents: .date)
                }
            }
            .font(.system(.body, design: .rounded))
            .scrollContentBackground(.hidden)
            .background(GrainientBackground().ignoresSafeArea())
            .navigationTitle(holding.name.isEmpty ? "New holding" : holding.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        holding.name = holding.name.trimmingCharacters(in: .whitespaces)
                        holding.quantity = Decimal(string: qty) ?? 0
                        holding.costPerUnit = Decimal(string: cost) ?? 0
                        holding.currentPrice = Decimal(string: price) ?? 0
                        onSave(holding)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark).tint(.white)
    }

    private func field(_ title: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
        }
    }
}

/// Trim a Decimal to a plain string without trailing zeros.
private func decimal(_ d: Decimal) -> String {
    let n = NSDecimalNumber(decimal: d)
    return n == n.rounding(accordingToBehavior: NSDecimalNumberHandler(
        roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false,
        raiseOnUnderflow: false, raiseOnDivideByZero: false))
        ? "\(n.intValue)" : "\(n)"
}
