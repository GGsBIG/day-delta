import SwiftUI

/// Portfolio tab: kind switcher, total value + P/L, and holdings grouped by stock.
/// Prices come from live quotes (gold is priced in TWD per 兩). Lives in the pager.
struct InvestmentsView: View {
    @State private var app = AppData.shared
    @State private var editing: Holding?
    @State private var viewingGroup: GroupKey?
    @State private var filter: String? = nil      // nil = All; else a kind name
    @State private var refreshing = false

    private struct GroupKey: Identifiable { let id: String }

    private var holdings: [Holding] {
        filter == nil ? app.holdings : app.holdings.filter { $0.kind == filter }
    }
    private var groups: [HoldingGroup] { groupHoldings(holdings) }

    private var totalValue: Decimal { holdings.reduce(0) { $0 + $1.marketValue } }
    private var totalCost: Decimal { holdings.reduce(0) { $0 + $1.cost } }
    private var totalGain: Decimal { totalValue - totalCost }
    private var gainPct: Double {
        let c = (totalCost as NSDecimalNumber).doubleValue
        guard c > 0 else { return 0 }
        return (totalGain as NSDecimalNumber).doubleValue / c * 100
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Investments") {
                if refreshing {
                    ProgressView()
                } else {
                    Button { Task { await refreshQuotes() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.appInk)
                    }
                }
                Button { editing = Holding(kind: kindUSStocks, name: "", quantity: 0, costPerUnit: 0, currentPrice: 0) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold)).foregroundStyle(Color.appInk)
                }
            }
            switcher
            if holdings.isEmpty {
                ContentUnavailableView("No investments", systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Tap + to add a holding."))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    Section { summary.listRowBackground(Color.clear) }
                    Section("Holdings") {
                        ForEach(groups) { g in
                            Button { viewingGroup = GroupKey(id: g.key) } label: { groupRow(g) }.buttonStyle(.plain)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        app.deleteHoldings(ids: g.lots.map(\.id))
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .refreshable { await refreshQuotes() }
            }
        }
        .preferredColorScheme(.dark).tint(.white)
        .sheet(item: $editing) { h in
            HoldingEditSheet(holding: h) { saved in app.saveHolding(saved); editing = nil }
        }
        .sheet(item: $viewingGroup) { key in
            HoldingGroupSheet(groupKey: key.id)
        }
        .task { await refreshQuotes() }
    }

    // MARK: Kind switcher (All / US / TW / Gold)

    private var switcher: some View {
        let kinds: [String?] = [nil] + investmentKinds.map { $0.name }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(kinds.indices, id: \.self) { i in
                    let k = kinds[i]
                    let on = filter == k
                    Button { filter = k } label: {
                        Text(k ?? "All")
                            .font(.system(.subheadline, design: .rounded)).fontWeight(.medium)
                            .foregroundStyle(on ? .white : Color.appInk)
                            .padding(.vertical, 8).padding(.horizontal, 16)
                            .background(Capsule().fill(on ? AnyShapeStyle(Color.appInk.opacity(0.9)) : AnyShapeStyle(Color.appInk.opacity(0.1))))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal).padding(.bottom, 4)
        }
    }

    /// Pull live prices once per unique symbol (+ gold via its own endpoint).
    private func refreshQuotes() async {
        let hasGold = app.holdings.contains { $0.kind == kindGold }
        let symbols = Set(app.holdings.filter { $0.kind != kindGold }.map(\.symbol).filter { !$0.isEmpty })
        guard hasGold || !symbols.isEmpty else { return }
        refreshing = true
        defer { refreshing = false }
        var prices: [String: Decimal] = [:]
        for s in symbols { if let p = await QuoteService.price(for: s) { prices[s] = p } }
        let gold = hasGold ? await QuoteService.goldPricePerTael() : nil
        var next = app.holdings
        for i in next.indices {
            if next[i].kind == kindGold { if let g = gold { next[i].currentPrice = g } }
            else if let p = prices[next[i].symbol] { next[i].currentPrice = p }
        }
        app.holdings = next
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

    // MARK: Group row

    private func groupRow(_ g: HoldingGroup) -> some View {
        HStack(spacing: 12) {
            Image(systemName: kindIcon(g.kind)).font(.system(size: 20))
                .foregroundStyle(Color(hex: kindColorHex(g.kind))).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.name.isEmpty ? g.kind : g.name).foregroundStyle(.white)
                Text("\(decimal(g.shares)) \(unitLabel(g.kind))"
                     + (g.lots.count > 1 ? " · \(g.lots.count) buys" : ""))
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatMoney(g.marketValue)).foregroundStyle(.white)
                Text("\(g.gain >= 0 ? "+" : "")\(formatMoney(g.gain))")
                    .font(.caption).foregroundStyle(g.gain >= 0 ? .green : .red)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.4))
        }
        .font(.system(.body, design: .rounded))
    }
}

/// Quantity unit for a kind: gold is counted in 兩, everything else in shares.
func unitLabel(_ kind: String) -> String { kind == kindGold ? "兩" : "shares" }

/// Detail for one symbol group: aggregate header + each purchase (add/edit/delete).
private struct HoldingGroupSheet: View {
    let groupKey: String
    @State private var app = AppData.shared
    @State private var editing: Holding?
    @Environment(\.dismiss) private var dismiss

    private var lots: [Holding] { groupHoldings(app.holdings).first { $0.key == groupKey }?.lots ?? [] }
    private var group: HoldingGroup { HoldingGroup(key: groupKey, lots: lots) }

    var body: some View {
        NavigationStack {
            List {
                Section { header.listRowBackground(Color.clear) }
                Section("Purchases") {
                    ForEach(lots) { lot in
                        Button { editing = lot } label: { lotRow(lot) }.buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) { app.deleteHoldings(ids: [lot.id]) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                    Button { editing = addLot() } label: { Label("Add purchase", systemImage: "plus") }
                        .listRowBackground(Color.white.opacity(0.06))
                }
            }
            .font(.system(.body, design: .rounded))
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(GrainientBackground().ignoresSafeArea())
            .navigationTitle(group.name.isEmpty ? group.kind : group.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editing) { h in
                HoldingEditSheet(holding: h) { saved in app.saveHolding(saved); editing = nil }
            }
        }
        .preferredColorScheme(.dark).tint(.white)
        .onChange(of: lots.count) { _, c in if c == 0 { dismiss() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Market value").font(.caption).foregroundStyle(.white.opacity(0.6))
            Text(formatMoney(group.marketValue))
                .font(.system(size: 34, weight: .thin, design: .rounded)).tracking(-1)
                .foregroundStyle(.white).minimumScaleFactor(0.4).lineLimit(1)
            HStack(spacing: 12) {
                Text("\(decimal(group.shares)) \(unitLabel(group.kind)) · cost \(formatMoney(group.cost))")
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
                Text("\(group.gain >= 0 ? "+" : "")\(formatMoney(group.gain))")
                    .font(.system(.subheadline, design: .rounded)).bold()
                    .foregroundStyle(group.gain >= 0 ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func lotRow(_ lot: Holding) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(lot.date, format: .dateTime.year().month().day()).foregroundStyle(.white)
                Text("\(decimal(lot.quantity)) \(unitLabel(lot.kind)) @ \(formatMoney(lot.costPerUnit))")
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatMoney(lot.marketValue)).foregroundStyle(.white)
                Text("\(lot.gain >= 0 ? "+" : "")\(formatMoney(lot.gain))")
                    .font(.caption).foregroundStyle(lot.gain >= 0 ? .green : .red)
            }
        }
    }

    private func addLot() -> Holding {
        Holding(kind: group.kind, name: group.name, symbol: group.symbol,
                quantity: 0, costPerUnit: 0, currentPrice: group.currentPrice)
    }
}

/// Add / edit one holding. Stocks pick a ticker from a bundled list; gold is in 兩.
private struct HoldingEditSheet: View {
    @State var holding: Holding
    let onSave: (Holding) -> Void
    @State private var app = AppData.shared
    @Environment(\.dismiss) private var dismiss

    @State private var qty: String    // shares (odd) / lots (whole) / 兩 (gold)
    @State private var cost: String
    @State private var price: String
    @State private var showPicker = false

    init(holding: Holding, onSave: @escaping (Holding) -> Void) {
        _holding = State(initialValue: holding)
        self.onSave = onSave
        let count = (holding.kind != kindGold && holding.wholeLot) ? holding.quantity / 1000 : holding.quantity
        _qty = State(initialValue: count == 0 ? "" : "\(count)")
        _cost = State(initialValue: holding.costPerUnit == 0 ? "" : "\(holding.costPerUnit)")
        _price = State(initialValue: holding.currentPrice == 0 ? "" : "\(holding.currentPrice)")
    }

    private var isGold: Bool { holding.kind == kindGold }
    private var isStock: Bool { holding.kind == kindUSStocks || holding.kind == kindTWStocks }

    var body: some View {
        NavigationStack {
            Form {
                Section("Instrument") {
                    Picker("Kind", selection: $holding.kind) {
                        ForEach(investmentKinds, id: \.name) { k in
                            Label(k.name, systemImage: k.icon).tag(k.name)
                        }
                    }
                    if isStock {
                        Button { showPicker = true } label: {
                            HStack {
                                Text("Stock").foregroundStyle(Color.appInk)
                                Spacer()
                                Text(holding.symbol.isEmpty ? "Select" : holding.symbol)
                                    .foregroundStyle(.secondary).lineLimit(1)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    TextField("Name (your label)", text: $holding.name)
                }
                Section("Position") {
                    if isStock {
                        Picker("Lot", selection: $holding.wholeLot) {
                            Text("Odd lot").tag(false)
                            Text("Whole lot (×1000)").tag(true)
                        }.pickerStyle(.segmented)
                    }
                    field(qtyLabel, $qty)
                    field(isGold ? "Cost per 兩" : "Cost per share", $cost)
                    field(isGold ? "Price per 兩" : "Current price", $price)
                    DatePicker("Date", selection: $holding.date, displayedComponents: .date)
                }
                Section {
                    Picker("Funding account", selection: $holding.accountID) {
                        Text("Unassigned").tag(UUID?.none)
                        ForEach(app.accounts) { a in Text(a.name).tag(UUID?.some(a.id)) }
                    }
                } footer: {
                    Text("Only buys with a funding account are recorded in the Ledger (and count as saved). Unassigned = Investments only.")
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
                        let count = Decimal(string: qty) ?? 0
                        holding.quantity = (isStock && holding.wholeLot) ? count * 1000 : count
                        holding.costPerUnit = Decimal(string: cost) ?? 0
                        holding.currentPrice = Decimal(string: price) ?? 0
                        if isGold { holding.symbol = "" }
                        onSave(holding)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                StockListView(kind: holding.kind) { symbol, name in
                    holding.symbol = symbol
                    if holding.name.isEmpty { holding.name = name }
                    Task {
                        if let p = await QuoteService.price(for: symbol) { price = "\(p)"; holding.currentPrice = p }
                    }
                }
            }
            .task { await autofillGoldPrice() }
        }
        .preferredColorScheme(.dark).tint(.white)
    }

    private var qtyLabel: String { isGold ? "兩 (taels)" : (holding.wholeLot ? "Lots" : "Shares") }

    /// Prefill a live gold price when adding a gold holding with no price yet.
    private func autofillGoldPrice() async {
        guard isGold, price.isEmpty, let g = await QuoteService.goldPricePerTael() else { return }
        price = "\(g)"
    }

    private func field(_ title: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 140)
        }
    }
}

/// Pick a ticker from the bundled list for a kind — locally filterable, no network.
private struct StockListView: View {
    let kind: String
    let onPick: (String, String) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var items: [(symbol: String, name: String)] {
        let all = stockList(for: kind)
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { $0.symbol.lowercased().contains(q) || $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List(items, id: \.symbol) { item in
                Button { onPick(item.symbol, item.name); dismiss() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.symbol).foregroundStyle(Color.appInk)
                            Text(item.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.white.opacity(0.06))
            }
            .font(.system(.body, design: .rounded))
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(GrainientBackground().ignoresSafeArea())
            .searchable(text: $query, prompt: "Filter")
            .navigationTitle("Select stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .preferredColorScheme(.dark).tint(.white)
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
