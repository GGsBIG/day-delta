import SwiftUI
import UIKit

/// App-wide UI constants. One corner radius so every rounded container matches.
enum UI { static let radius: CGFloat = 20 }

extension Color {
    /// "#RRGGBB" for persisting a chosen color. Pairs with `Color(hex:)`.
    func toHex() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }

    /// A lighter, slightly less saturated variant — used to build accent gradients.
    func lighter(_ amount: Double = 0.3) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: max(0, Double(s) - amount * 0.6),
                     brightness: min(1, Double(b) + amount))
    }
}

/// A two-stop gradient from a lighter tint to the accent color.
func accentGradient(_ hex: String) -> LinearGradient {
    let c = Color(hex: hex)
    return LinearGradient(colors: [c.lighter(0.3), c], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension View {
    /// iOS 26 "Liquid Glass" background clipped to `shape`; frosted-material
    /// fallback on older systems. Used for every panel so the app matches the
    /// native glass look.
    @ViewBuilder
    func liquidGlass(_ shape: some Shape) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            // Thin, light frost: a faint white behind the blur lifts it off the
            // dark background, with an Apple-style hairline edge.
            self.background(shape.fill(.white.opacity(0.12)))
                .background(shape.fill(.ultraThinMaterial))
                .overlay(shape.stroke(.white.opacity(0.25), lineWidth: 0.5))
        }
    }

    /// Rounded-rect liquid glass (default corner radius).
    func liquidGlass(_ radius: CGFloat = UI.radius) -> some View {
        liquidGlass(RoundedRectangle(cornerRadius: radius))
    }
}

/// Relative luminance (WCAG) of a "#RRGGBB" color, 0 (black) … 1 (white).
func relativeLuminance(_ hex: String) -> Double {
    let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard s.count == 6, let v = UInt64(s, radix: 16) else { return 0 }
    func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    let r = lin(Double((v >> 16) & 0xFF) / 255)
    let g = lin(Double((v >> 8) & 0xFF) / 255)
    let b = lin(Double(v & 0xFF) / 255)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

extension Color {
    /// Maximum-contrast ink (white or black) for the chosen background color, so
    /// text and graphics are never swallowed by it. Reads the stored background.
    static var appInk: Color {
        let hex = UserDefaults.standard.string(forKey: "accountsBgHex") ?? "#5227FF"
        return relativeLuminance(hex) > 0.45 ? .black : .white
    }
}

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
