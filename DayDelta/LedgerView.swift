import SwiftUI

/// The Ledger tab: a month calendar with a per-day transaction list; edit opens
/// the category/account manager. Owns the shared txn/category/account state.
struct LedgerView: View {
    @State private var txns: [Txn] = TxnStore.load()
    @State private var categories: [Category] = CategoryStore.load()
    @State private var accounts: [Account] = AccountStore.load()
    @State private var editingTxn: Txn?
    @State private var managing = false
    @State private var monthAnchor = Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())

    /// Driven by the bottom-bar Add button in RootView. Defaults to a constant so
    /// LedgerView still compiles/previews standalone.
    @Binding var requestAddTxn: Bool

    init(requestAddTxn: Binding<Bool> = .constant(false)) {
        _requestAddTxn = requestAddTxn
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Ledger") {
                Button("Edit") { managing = true }.foregroundStyle(Color.appInk)
            }
            ledgerList
        }
        .sheet(isPresented: $requestAddTxn) {
            TxnEditView(txn: nil, categories: categories, accounts: accounts,
                        defaultDate: selectedDay) { saved in
                txns.append(saved); persist()
            }
        }
        .sheet(item: $editingTxn) { t in
            TxnEditView(txn: t, categories: categories, accounts: accounts) { saved in
                if let i = txns.firstIndex(where: { $0.id == saved.id }) { txns[i] = saved }
                persist()
            }
        }
        .sheet(isPresented: $managing) {
            ManageView(categories: $categories, accounts: $accounts)
                .onDisappear {
                    CategoryStore.save(categories)
                    AccountStore.save(accounts)
                }
        }
        // Pick up changes made by Backup import in the other tab.
        .onAppear {
            txns = TxnStore.load()
            categories = CategoryStore.load()
            accounts = AccountStore.load()
        }
    }

    // MARK: Ledger

    private var ledgerList: some View {
        ScrollView {
            VStack(spacing: 24) {
                MonthCalendarView(
                    monthAnchor: monthAnchor,
                    txns: txns,
                    categories: categories,
                    selectedDay: $selectedDay,
                    onPrevMonth: { changeMonth(-1) },
                    onNextMonth: { changeMonth(1) }
                )

                selectedDayList
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var selectedDayList: some View {
        let rows = txnsOn(txns, day: selectedDay).sorted { $0.date > $1.date }
        VStack(alignment: .leading, spacing: 10) {
            Text(dateLabel(selectedDay))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.appInk.opacity(0.6))
            if rows.isEmpty {
                Text("No transactions")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(Color.appInk.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)
            } else {
                ForEach(rows) { t in
                    row(t)
                        .contentShape(Rectangle())
                        .onTapGesture { editingTxn = t }
                        .contextMenu {
                            Button(role: .destructive) { delete(t) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func changeMonth(_ delta: Int) {
        monthAnchor = addMonths(delta, to: monthAnchor)
    }

    /// Delete a selected-day transaction by id.
    private func delete(_ t: Txn) {
        txns.removeAll { $0.id == t.id }
        persist()
    }

    private func row(_ t: Txn) -> some View {
        let c = categories.first { $0.id == t.categoryID }
        return HStack {
            CategoryBadge(category: c ?? Category(name: "—", type: t.type, icon: nil, colorHex: "#9CA3AF"), size: 30)
            VStack(alignment: .leading) {
                Text(c?.name ?? "—").font(.system(.body, design: .rounded))
                if let note = t.note {
                    Text(note).font(.caption).foregroundStyle(Color.appInk.opacity(0.6))
                }
            }
            Spacer()
            Text((t.type == .expense ? "-" : "+") + formatMoney(t.amount))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(t.type == .expense ? .red : .green)
        }
    }

    private func persist() { TxnStore.save(txns) }
}
