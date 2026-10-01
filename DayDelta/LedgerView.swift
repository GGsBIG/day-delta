import SwiftUI

/// "#RRGGBB" -> Color. Falls back to gray on a malformed string.
extension Color {
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let v = UInt64(s, radix: 16) else { self = .gray; return }
        self = Color(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255)
    }
}

/// The Money tab: a segmented switch between the Ledger and Stats
/// sub-pages, owning the shared txn/category state.
struct LedgerView: View {
    @State private var txns: [Txn] = TxnStore.load()
    @State private var categories: [Category] = CategoryStore.load()
    @State private var page = 0
    @State private var editingTxn: Txn?
    @State private var addingTxn = false
    @State private var managingCategories = false

    var body: some View {
        NavigationStack {
            Group {
                if page == 0 {
                    ledgerList
                } else {
                    StatsView(txns: txns, categories: categories)
                }
            }
            .background(Color.black)
            .navigationTitle("Money")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $page) {
                        Text("Ledger").tag(0)
                        Text("Stats").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { addingTxn = true } label: { Label("Add", systemImage: "plus") }
                        Button { managingCategories = true } label: {
                            Label("Categories", systemImage: "tag")
                        }
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $addingTxn) {
                TxnEditView(txn: nil, categories: categories) { saved in
                    txns.append(saved); persist()
                }
            }
            .sheet(item: $editingTxn) { t in
                TxnEditView(txn: t, categories: categories) { saved in
                    if let i = txns.firstIndex(where: { $0.id == saved.id }) { txns[i] = saved }
                    persist()
                }
            }
            .sheet(isPresented: $managingCategories) {
                NavigationStack { CategoryManagerView(categories: $categories) }
                    .preferredColorScheme(.dark).tint(.white)
                    .onDisappear { CategoryStore.save(categories) }
            }
        }
        // Pick up changes made by Backup import in the other tab.
        .onAppear {
            txns = TxnStore.load()
            categories = CategoryStore.load()
        }
    }

    // MARK: Ledger

    private var ledgerList: some View {
        Group {
            if txns.isEmpty {
                ContentUnavailableView("No records", systemImage: "list.bullet",
                    description: Text("Tap + to add income or expense."))
            } else {
                List {
                    summarySection
                    ForEach(dayGroups, id: \.0) { day, rows in
                        Section(dateLabel(day)) {
                            ForEach(rows) { t in
                                row(t)
                                    .listRowBackground(Color.black)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingTxn = t }
                            }
                            .onDelete { deleteInDay(day: day, offsets: $0) }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var summarySection: some View {
        let month = txnsInPeriod(txns, period: .month, containing: Date())
        let income = categoryTotals(month, type: .income).reduce(Decimal(0)) { $0 + $1.total }
        let expense = categoryTotals(month, type: .expense).reduce(Decimal(0)) { $0 + $1.total }
        return Section("This month") {
            HStack {
                summaryCell("Income", income, .green)
                summaryCell("Expense", expense, .red)
                summaryCell("Net", income - expense, .white)
            }
            .listRowBackground(Color.black)
        }
    }

    private func summaryCell(_ label: String, _ value: Decimal, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.gray)
            Text(formatMoney(value)).font(.system(.callout, design: .monospaced))
                .foregroundStyle(color).minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ t: Txn) -> some View {
        let c = categories.first { $0.id == t.categoryID }
        return HStack {
            Circle().fill(Color(hex: c?.colorHex ?? "#9CA3AF")).frame(width: 12, height: 12)
            VStack(alignment: .leading) {
                Text(c?.name ?? "—").font(.system(.body, design: .monospaced))
                if let note = t.note {
                    Text(note).font(.caption).foregroundStyle(.gray)
                }
            }
            Spacer()
            Text((t.type == .expense ? "-" : "+") + formatMoney(t.amount))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(t.type == .expense ? .red : .green)
        }
    }

    /// Txns grouped by start-of-day, newest day first.
    private var dayGroups: [(Date, [Txn])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: txns) { cal.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!.sorted { $0.date > $1.date }) }
    }

    private func deleteInDay(day: Date, offsets: IndexSet) {
        let rows = (dayGroups.first { $0.0 == day }?.1) ?? []
        let ids = offsets.map { rows[$0].id }
        txns.removeAll { ids.contains($0.id) }
        persist()
    }

    private func persist() { TxnStore.save(txns) }
}
