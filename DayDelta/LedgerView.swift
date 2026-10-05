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
        NavigationStack {
            ledgerList
            .background(GrainientBackground().ignoresSafeArea())
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("Ledger")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { managing = true }
                }
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
                .foregroundStyle(.gray)
            if rows.isEmpty {
                Text("No transactions")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
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
            Circle().fill(Color(hex: c?.colorHex ?? "#9CA3AF")).frame(width: 12, height: 12)
            VStack(alignment: .leading) {
                Text(c?.name ?? "—").font(.system(.body, design: .rounded))
                if let note = t.note {
                    Text(note).font(.caption).foregroundStyle(.gray)
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
