import SwiftUI
import Charts

/// Accounts overview: a top-left account switcher (avatar stack + menu), the
/// selected account's balance left-aligned with rolling digits, a Week/Month/Year
/// toggle, and a running Total Balance curve. Everything fits one page — no scroll.
struct AccountsView: View {
    @State private var txns: [Txn] = TxnStore.load()
    @State private var accounts: [Account] = AccountStore.load()

    /// nil = all accounts (grand total); otherwise the chosen account.
    @State private var selected: UUID? = nil
    @State private var period: StatPeriod = .month
    @State private var showingManage = false

    private var current: Account? { accounts.first { $0.id == selected } }
    private var selectedName: String { current?.name ?? "All accounts" }
    private var tint: Color { current.map { Color(hex: $0.colorHex) } ?? .white }

    private var balance: Decimal {
        selected == nil
            ? txns.reduce(Decimal(0)) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
            : accountBalance(txns, accountID: selected)
    }

    private var series: [BalancePoint] { balanceSeries(txns, scope: selected, period: period) }

    var body: some View {
        ZStack {
            // Subtle dark gradient behind everything.
            LinearGradient(colors: [Color(white: 0.11), .black],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    RadialGradient(colors: [tint.opacity(0.18), .clear],
                                   center: .top, startRadius: 0, endRadius: 320)
                        .ignoresSafeArea()
                        .animation(.smooth(duration: 0.5), value: selected)
                }

            VStack(alignment: .leading, spacing: 20) {
                switcher

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedName.uppercased())
                        .font(.caption).foregroundStyle(.gray).tracking(1)
                    Text(formatMoney(balance))
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.4).lineLimit(1)
                        .contentTransition(.numericText(value: (balance as NSDecimalNumber).doubleValue))
                }

                periodToggle

                if txns.isEmpty {
                    ContentUnavailableView("No activity", systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Add transactions in the Ledger to see your balance curve."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    BalanceChart(series: series, tint: tint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(period)   // redraw-in on range change
                        .transition(.opacity)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.snappy(duration: 0.45), value: balance)
            .animation(.snappy(duration: 0.45), value: period)
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .sheet(isPresented: $showingManage) {
            NavigationStack { AccountManagerView(accounts: $accounts) }
                .preferredColorScheme(.dark).tint(.white)
        }
        .onChange(of: accounts) { _, new in
            AccountStore.save(new)
            if let selected, !new.contains(where: { $0.id == selected }) { self.selected = nil }
        }
        .onAppear {
            txns = TxnStore.load()
            accounts = AccountStore.load()
        }
    }

    // MARK: Switcher (top-left)

    private var switcher: some View {
        Menu {
            Picker("Account", selection: $selected) {
                Text("All accounts").tag(UUID?.none)
                ForEach(accounts) { a in Text(a.name).tag(UUID?.some(a.id)) }
            }
            Divider()
            Button { showingManage = true } label: {
                Label("Manage accounts…", systemImage: "slider.horizontal.3")
            }
        } label: {
            HStack(spacing: 10) {
                AvatarStack(accounts: accounts, highlight: selected)
                Text(selectedName)
                    .font(.system(.subheadline, design: .monospaced)).foregroundStyle(.white)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold)).foregroundStyle(.gray)
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            .background(Capsule().fill(Color(white: 0.14)))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }

    // MARK: Period toggle

    private var periodToggle: some View {
        Picker("Range", selection: $period) {
            ForEach(StatPeriod.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: period)
    }
}

/// Overlapping circle stack — like a team avatar group — showing the first few
/// accounts with a "+N" bubble for the rest. The selected account floats to the
/// front and brightens.
private struct AvatarStack: View {
    let accounts: [Account]
    let highlight: UUID?
    var max = 4
    private let size: CGFloat = 28

    var body: some View {
        let visible = Array(accounts.prefix(max))
        let overflow = accounts.count - visible.count
        HStack(spacing: -10) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { i, a in
                avatar(fill: Color(hex: a.colorHex), text: initials(a.name))
                    .opacity(highlight == nil || highlight == a.id ? 1 : 0.55)
                    .scaleEffect(highlight == a.id ? 1.12 : 1)
                    .zIndex(highlight == a.id ? 100 : Double(max - i))
            }
            if overflow > 0 {
                avatar(fill: Color(white: 0.25), text: "+\(overflow)")
                    .contentTransition(.numericText())
                    .zIndex(0)
            }
        }
        .animation(.bouncy(duration: 0.4), value: highlight)
    }

    private func avatar(fill: Color, text: String) -> some View {
        Circle().fill(fill)
            .frame(width: size, height: size)
            .overlay(Text(text).font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1))
            .overlay(Circle().strokeBorder(.black, lineWidth: 2))
    }

    /// Up to two initials: first letter of the first two words, else first two chars.
    private func initials(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 { return (String(words[0].prefix(1)) + words[1].prefix(1)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }
}

/// Running Total Balance curve. Smooth monotone line + faint area fill; drag to
/// scrub a crosshair that reads out the balance on that day.
private struct BalanceChart: View {
    let series: [BalancePoint]
    let tint: Color
    @State private var active: BalancePoint?

    var body: some View {
        Chart {
            ForEach(series) { p in
                AreaMark(x: .value("Date", p.date), y: .value("Balance", p.doubleValue))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [tint.opacity(0.3), tint.opacity(0.02)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", p.date), y: .value("Balance", p.doubleValue))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            if let active {
                RuleMark(x: .value("Date", active.date))
                    .foregroundStyle(.white.opacity(0.25))
                PointMark(x: .value("Date", active.date), y: .value("Balance", active.doubleValue))
                    .foregroundStyle(tint)
                    .symbolSize(90)
                    .annotation(position: .top, spacing: 8,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(active.date, format: .dateTime.month().day())
                                .font(.caption2).foregroundStyle(.gray)
                            Text(formatMoney(active.balance))
                                .font(.system(.caption, design: .monospaced)).bold().foregroundStyle(.white)
                        }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.16)))
                    }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(.gray)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) {
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.notation(.compactName))
                    .foregroundStyle(.gray)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            guard let date: Date = proxy.value(atX: g.location.x) else { return }
                            active = series.min {
                                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                            }
                        }
                        .onEnded { _ in active = nil })
            }
        }
    }
}
