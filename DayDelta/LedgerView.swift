import SwiftUI

/// The Ledger tab: a month calendar with a per-day transaction list; edit opens
/// the category/account manager. Owns the shared txn/category/account state.
struct LedgerView: View {
    @State private var app = AppData.shared
    private var txns: [Txn] { app.txns }
    private var categories: [Category] { app.categories }
    private var accounts: [Account] { app.accounts }
    @State private var editingTxn: Txn?
    @State private var managing = false
    @State private var showingDays = false
    @State private var monthAnchor = Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Ledger") {
                Button { showingDays = true } label: { Image(systemName: "calendar") }
                Button("Edit") { managing = true }
            }
            ledgerList
        }
        .sheet(item: $editingTxn) { t in
            TxnEditView(txn: t, categories: categories, accounts: accounts) { saved in
                app.updateTxn(saved); persist()
            }
        }
        .sheet(isPresented: $managing) {
            ManageView(categories: $app.categories, accounts: $app.accounts)
        }
        .fullScreenCover(isPresented: $showingDays) {
            ZStack {
                GrainientBackground().ignoresSafeArea()
                ContentView(onClose: { showingDays = false })
            }
            .preferredColorScheme(.dark).tint(.white)
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
        app.deleteTxn(id: t.id)
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

    /// AppData persists txns automatically; this only keeps notifications in sync.
    private func persist() {}
}
