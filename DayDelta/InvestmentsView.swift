import SwiftUI

/// Portfolio overview: total market value, cost, and unrealized P/L, plus a list
/// of holdings. Prices are entered by hand. Opened as a sheet from Accounts.
struct InvestmentsView: View {
    @State private var holdings: [Holding] = HoldingStore.load()
    @State private var accounts: [Account] = AccountStore.load()
    @State private var editing: Holding?
    @State private var refreshing = false

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
                if refreshing { ProgressView() }
                else {
                    Button { Task { await refreshQuotes() } } label: {
                        Image(systemName: "arrow.clockwise").foregroundStyle(Color.appInk)
                    }
                }
                Button { editing = Holding(kind: investmentKinds[0].name, name: "",
                                           quantity: 0, costPerUnit: 0, currentPrice: 0) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28)).foregroundStyle(Color.appInk)
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
                        ForEach(holdings) { h in
                            Button { editing = h } label: { row(h) }.buttonStyle(.plain)
                        }
                        .onDelete { offsets in delete(offsets) }
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
                upsert(saved)
                editing = nil
            }
        }
        .onAppear {
            holdings = HoldingStore.load()
            accounts = AccountStore.load()
        }
        .task { await refreshQuotes() }
    }

    // MARK: Persistence + linked txn

    /// Save a holding and upsert its linked investment expense txn so the cost
    /// counts as "saved" (and shows in the Ledger).
    private func upsert(_ h: Holding) {
        var holding = h
        var txns = TxnStore.load()
        let cat = ensureInvestmentCategory()
        if let tid = holding.txnID, let i = txns.firstIndex(where: { $0.id == tid }) {
            txns[i].amount = holding.cost
            txns[i].date = holding.date
            txns[i].note = holding.name
            txns[i].accountID = holding.accountID
            txns[i].categoryID = cat.id
        } else {
            let t = Txn(type: .expense, amount: holding.cost, categoryID: cat.id,
                        date: holding.date, note: holding.name, accountID: holding.accountID)
            holding.txnID = t.id
            txns.append(t)
        }
        TxnStore.save(txns)

        if let i = holdings.firstIndex(where: { $0.id == holding.id }) { holdings[i] = holding }
        else { holdings.append(holding) }
        HoldingStore.save(holdings)
    }

    private func delete(_ offsets: IndexSet) {
        let removed = offsets.map { holdings[$0] }
        let txnIDs = Set(removed.compactMap(\.txnID))
        if !txnIDs.isEmpty {
            var txns = TxnStore.load()
            txns.removeAll { txnIDs.contains($0.id) }
            TxnStore.save(txns)
        }
        holdings.remove(atOffsets: offsets)
        HoldingStore.save(holdings)
    }

    /// Pull live prices for every holding that has a symbol.
    private func refreshQuotes() async {
        guard holdings.contains(where: { !$0.symbol.isEmpty }) else { return }
        refreshing = true
        defer { refreshing = false }
        for i in holdings.indices where !holdings[i].symbol.isEmpty {
            if let p = await QuoteService.price(for: holdings[i].symbol) {
                holdings[i].currentPrice = p
            }
        }
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
