import SwiftUI

/// Portfolio overview: total market value, cost, and unrealized P/L, plus a list
/// of holdings. Prices are entered by hand. Opened as a sheet from Accounts.
struct InvestmentsView: View {
    @State private var holdings: [Holding] = HoldingStore.load()
    @State private var accounts: [Account] = AccountStore.load()
    @State private var editing: Holding?
    @State private var viewingGroup: GroupKey?
    @State private var refreshing = false

    private struct GroupKey: Identifiable { let id: String }

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
                Button { editing = newHolding() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold)).foregroundStyle(Color.appInk)
                }
            }
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
                                        HoldingService.delete(ids: g.lots.map(\.id)); reload()
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
            HoldingEditSheet(holding: h, accounts: accounts) { saved in
                HoldingService.save(saved); reload(); editing = nil
            }
        }
        .sheet(item: $viewingGroup) { key in
            HoldingGroupSheet(groupKey: key.id, accounts: accounts) { reload() }
        }
        .onAppear { reload(); accounts = AccountStore.load() }
        .task { await refreshQuotes() }
    }

    private func newHolding() -> Holding {
        Holding(kind: investmentKinds[0].name, name: "", quantity: 0, costPerUnit: 0, currentPrice: 0)
    }

    private func reload() { holdings = HoldingStore.load() }

    /// Pull live prices once per unique symbol, applied to all lots of that symbol.
    private func refreshQuotes() async {
        let symbols = Set(holdings.map(\.symbol).filter { !$0.isEmpty })
        guard !symbols.isEmpty else { return }
        refreshing = true
        defer { refreshing = false }
        var prices: [String: Decimal] = [:]
        for s in symbols { if let p = await QuoteService.price(for: s) { prices[s] = p } }
        for i in holdings.indices { if let p = prices[holdings[i].symbol] { holdings[i].currentPrice = p } }
        HoldingStore.save(holdings)
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
                Text("\(decimal(g.shares)) shares"
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

/// Detail for one symbol group: aggregate header + each individual purchase, with
/// add / edit / delete per lot.
private struct HoldingGroupSheet: View {
    let groupKey: String
    let accounts: [Account]
    let onChange: () -> Void
    @State private var lots: [Holding] = []
    @State private var editing: Holding?
    @Environment(\.dismiss) private var dismiss

    private var group: HoldingGroup { HoldingGroup(key: groupKey, lots: lots) }

    var body: some View {
        NavigationStack {
            List {
                Section { header.listRowBackground(Color.clear) }
                Section("Purchases") {
                    ForEach(lots) { lot in
                        Button { editing = lot } label: { lotRow(lot) }.buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    HoldingService.delete(ids: [lot.id]); reload()
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                    Button { editing = addLot() } label: {
                        Label("Add purchase", systemImage: "plus")
                    }
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
                HoldingEditSheet(holding: h, accounts: accounts) { saved in
                    HoldingService.save(saved); reload(); editing = nil
                }
            }
        }
        .preferredColorScheme(.dark).tint(.white)
        .onAppear { reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Market value").font(.caption).foregroundStyle(.white.opacity(0.6))
            Text(formatMoney(group.marketValue))
                .font(.system(size: 34, weight: .thin, design: .rounded)).tracking(-1)
                .foregroundStyle(.white).minimumScaleFactor(0.4).lineLimit(1)
            HStack(spacing: 12) {
                Text("\(decimal(group.shares)) shares · cost \(formatMoney(group.cost))")
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
                Text("\(decimal(lot.quantity)) sh @ \(formatMoney(lot.costPerUnit))")
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

    /// A new lot pre-filled with this group's instrument + latest price.
    private func addLot() -> Holding {
        Holding(kind: group.kind, name: group.name, symbol: group.symbol,
                quantity: 0, costPerUnit: 0, currentPrice: group.currentPrice)
    }

    private func reload() {
        lots = groupHoldings(HoldingStore.load()).first { $0.key == groupKey }?.lots ?? []
        onChange()
        if lots.isEmpty { dismiss() }
    }
}

/// Add / edit one holding. Decimal fields use the decimal keypad.
private struct HoldingEditSheet: View {
    @State var holding: Holding
    let accounts: [Account]
    let onSave: (Holding) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var qty: String    // count of shares (odd lot) or lots (whole lot)
    @State private var cost: String
    @State private var price: String
    @State private var showSearch = false

    init(holding: Holding, accounts: [Account], onSave: @escaping (Holding) -> Void) {
        _holding = State(initialValue: holding)
        self.accounts = accounts
        self.onSave = onSave
        let count = holding.wholeLot ? holding.quantity / 1000 : holding.quantity
        _qty = State(initialValue: count == 0 ? "" : "\(count)")
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
                    Button { showSearch = true } label: {
                        HStack {
                            Text("Stock").foregroundStyle(Color.appInk)
                            Spacer()
                            Text(holding.symbol.isEmpty ? "Select" : "\(holding.name) · \(holding.symbol)")
                                .foregroundStyle(.secondary).lineLimit(1)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Position") {
                    Picker("Lot", selection: $holding.wholeLot) {
                        Text("Odd lot").tag(false)
                        Text("Whole lot (×1000)").tag(true)
                    }.pickerStyle(.segmented)
                    field(holding.wholeLot ? "Lots" : "Shares", $qty)
                    field("Cost per share", $cost)
                    field("Current price", $price)
                    DatePicker("Date", selection: $holding.date, displayedComponents: .date)
                }
                Section {
                    Picker("Funding account", selection: $holding.accountID) {
                        Text("Unassigned").tag(UUID?.none)
                        ForEach(accounts) { a in Text(a.name).tag(UUID?.some(a.id)) }
                    }
                } footer: {
                    Text("Buying this holding records its cost as an investment expense, so it counts as saved (not spent).")
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
                        holding.quantity = holding.wholeLot ? count * 1000 : count
                        holding.costPerUnit = Decimal(string: cost) ?? 0
                        holding.currentPrice = Decimal(string: price) ?? 0
                        onSave(holding)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                StockSearchView(preferTW: holding.kind == "TW Stocks") { match in
                    holding.symbol = match.symbol
                    holding.name = match.name
                    Task {
                        if let p = await QuoteService.price(for: match.symbol) {
                            price = "\(p)"; holding.currentPrice = p
                        }
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

/// Search instruments by name/symbol (Yahoo) and pick one — no manual typing.
private struct StockSearchView: View {
    var preferTW = false
    let onPick: (SymbolMatch) -> Void
    @State private var query = ""
    @State private var results: [SymbolMatch] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(results) { m in
                Button { onPick(m); dismiss() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.symbol).foregroundStyle(Color.appInk)
                            Text(m.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(m.exchange).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.white.opacity(0.06))
            }
            .font(.system(.body, design: .rounded))
            .scrollContentBackground(.hidden)
            .background(GrainientBackground().ignoresSafeArea())
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView("Search a stock", systemImage: "magnifyingglass",
                        description: Text("Type a name or symbol, e.g. Apple, 2330, BTC."))
                }
            }
            .searchable(text: $query, prompt: "Name or symbol")
            .navigationTitle("Select")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .preferredColorScheme(.dark).tint(.white)
        .task(id: query) {
            try? await Task.sleep(nanoseconds: 300_000_000)   // debounce
            guard !Task.isCancelled else { return }
            // TW stocks: a bare numeric code like "2330" → search "2330.TW".
            let raw = query.trimmingCharacters(in: .whitespaces)
            let q = (preferTW && !raw.isEmpty && raw.allSatisfy(\.isNumber)) ? raw + ".TW" : raw
            results = await QuoteService.search(q)
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
