import SwiftUI
import Charts

/// Accounts overview, laid out like a modern wallet dashboard: greeting + account
/// switcher on top, the selected balance with a period-change pill, Week/Month/Year
/// chips, and a "This period" card with the balance curve and expense/income
/// totals. Green theme, one page, no scroll.
struct AccountsView: View {
    @State private var txns: [Txn] = TxnStore.load()
    @State private var accounts: [Account] = AccountStore.load()

    /// nil = all accounts (grand total); otherwise the chosen account.
    @State private var selected: UUID? = nil
    @State private var period: StatPeriod = .month
    @State private var showingManage = false

    private enum Palette {
        static let text = Color(hex: "#78350F")                            // deep amber brown
        static let textSoft = Color(hex: "#92400E")
        static let accent = Color(hex: "#F59E0B")                          // honey amber
        static let accent2 = Color(hex: "#D97706")                         // ember
        static let card = Color.white.opacity(0.55)
        static let subcard = Color.white.opacity(0.4)
        static let stroke = Color(hex: "#B45309").opacity(0.18)
    }

    private var current: Account? { accounts.first { $0.id == selected } }
    private var selectedName: String { current?.name ?? "All accounts" }

    private var balance: Decimal {
        selected == nil
            ? txns.reduce(Decimal(0)) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
            : accountBalance(txns, accountID: selected)
    }

    private var series: [BalancePoint] { balanceSeries(txns, scope: selected, period: period) }

    /// Txns for the selected account within the current calendar period.
    private var periodScoped: [Txn] {
        let base = selected == nil ? txns : txns.filter { $0.accountID == selected }
        return txnsInPeriod(base, period: period, containing: Date())
    }
    private var expenseTotal: Decimal { periodScoped.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount } }
    private var incomeTotal: Decimal { periodScoped.filter { $0.type == .income }.reduce(0) { $0 + $1.amount } }

    /// Balance change across the curve, as a percent of where it started.
    private var periodPct: Double {
        guard let first = series.first?.doubleValue, let last = series.last?.doubleValue, first != 0 else { return 0 }
        return (last - first) / abs(first) * 100
    }

    var body: some View {
        ZStack {
            background
            VStack(alignment: .leading, spacing: 18) {
                header
                balanceBlock
                chips
                card
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.snappy(duration: 0.45), value: balance)
            .animation(.snappy(duration: 0.45), value: period)
            .animation(.snappy(duration: 0.45), value: selected)
        }
        .preferredColorScheme(.light)
        .tint(Palette.accent2)
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

    // MARK: Background

    private var background: some View { HoneyEmberBackground() }

    // MARK: Header (greeting + switcher)

    private var header: some View {
        HStack(spacing: 12) {
            AvatarStack(accounts: accounts, highlight: selected)
            VStack(alignment: .leading, spacing: 1) {
                Text("Welcome back").font(.caption).foregroundStyle(Palette.textSoft.opacity(0.8))
                Text(selectedName).font(.system(.headline, design: .rounded)).bold()
                    .foregroundStyle(Palette.text).lineLimit(1)
            }
            Spacer()
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
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.text)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Palette.card))
                    .overlay(Circle().strokeBorder(Palette.stroke))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: selected)
        }
    }

    // MARK: Balance block

    private var balanceBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("Spend Account").font(.system(.title3, design: .rounded))
                    .foregroundStyle(Palette.textSoft)
                Spacer()
            }
            Text(formatMoney(balance))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text).minimumScaleFactor(0.4).lineLimit(1)
                .contentTransition(.numericText(value: (balance as NSDecimalNumber).doubleValue))
            HStack(spacing: 10) {
                Label(periodPct >= 0 ? "You've saved this \(period.label.lowercased())!"
                                     : "Spending up this \(period.label.lowercased())",
                      systemImage: "sparkles")
                    .font(.system(.subheadline, design: .rounded)).foregroundStyle(Palette.textSoft)
                    .labelStyle(.titleAndIcon)
                Text(String(format: "%+.2f%%", periodPct))
                    .font(.system(.caption, design: .rounded).bold()).foregroundStyle(.white)
                    .padding(.vertical, 5).padding(.horizontal, 10)
                    .background(Capsule().fill(LinearGradient(
                        colors: [Palette.accent, Palette.accent2],
                        startPoint: .leading, endPoint: .trailing)))
                    .contentTransition(.numericText(value: periodPct))
            }
        }
    }

    // MARK: Period chips

    private var chips: some View {
        HStack(spacing: 10) {
            ForEach(StatPeriod.allCases, id: \.self) { p in
                let on = p == period
                Button { period = p } label: {
                    Text(p.label)
                        .font(.system(.subheadline, design: .rounded)).fontWeight(.medium)
                        .foregroundStyle(on ? .white : Palette.text)
                        .padding(.vertical, 11).padding(.horizontal, 22)
                        .background(Capsule().fill(on
                            ? AnyShapeStyle(LinearGradient(colors: [Palette.accent, Palette.accent2],
                                                           startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Palette.card)))
                        .overlay(Capsule().strokeBorder(on ? .clear : Palette.stroke))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .sensoryFeedback(.selection, trigger: period)
    }

    // MARK: This-period card

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(periodTitle).font(.system(.title3, design: .rounded)).bold().foregroundStyle(Palette.text)
                    Text(rangeText).font(.caption).foregroundStyle(Palette.textSoft.opacity(0.8))
                }
                Spacer()
                Button(action: cycleAccount) {
                    Image(systemName: "chevron.left.chevron.right")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Palette.subcard))
                        .overlay(Circle().strokeBorder(Palette.stroke))
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatMoney(series.last?.balance ?? balance))
                        .font(.system(.title, design: .rounded)).bold().foregroundStyle(Palette.text)
                        .minimumScaleFactor(0.5).lineLimit(1)
                        .contentTransition(.numericText(value: (series.last?.doubleValue ?? 0)))
                    Text("Balance in wallet").font(.caption).foregroundStyle(Palette.textSoft.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                BalanceChart(series: series, tint: Palette.accent2, compact: true)
                    .frame(width: 150, height: 66)
                    .id(period)
            }

            HStack(spacing: 12) {
                miniStat("Total Expenses", expenseTotal)
                miniStat("Net Income", incomeTotal)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 28).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Palette.stroke))
        .padding(.bottom, 4)
    }

    private func miniStat(_ title: String, _ value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(.subheadline, design: .rounded)).foregroundStyle(Palette.textSoft)
            Text(formatMoney(value)).font(.system(.title3, design: .rounded)).bold()
                .foregroundStyle(Palette.text).minimumScaleFactor(0.5).lineLimit(1)
                .contentTransition(.numericText(value: (value as NSDecimalNumber).doubleValue))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Palette.subcard))
    }

    // MARK: Derived labels & actions

    private var periodTitle: String {
        switch period { case .week: "This Week"; case .month: "This Month"; case .year: "This Year" }
    }

    private var rangeText: String {
        let cal = Calendar.current
        let comp: Calendar.Component = period == .week ? .weekOfYear : period == .month ? .month : .year
        guard let interval = cal.dateInterval(of: comp, for: Date()) else { return "" }
        if period == .year { return Date().formatted(.dateTime.year()) }
        let end = cal.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let f = Date.FormatStyle().weekday(.abbreviated).day(.twoDigits).month(.abbreviated)
        return "\(interval.start.formatted(f)) – \(end.formatted(f))"
    }

    /// The ‹› button steps through All → each account → back to All.
    private func cycleAccount() {
        let ids: [UUID?] = [nil] + accounts.map { $0.id }
        let i = ids.firstIndex(of: selected) ?? 0
        selected = ids[(i + 1) % ids.count]
    }
}

/// Overlapping circle stack — like a team avatar group — showing the first few
/// accounts with a "+N" bubble for the rest. The selected account floats to the
/// front and brightens.
private struct AvatarStack: View {
    let accounts: [Account]
    let highlight: UUID?
    var max = 4
    private let size: CGFloat = 40

    var body: some View {
        let visible = Array(accounts.prefix(max))
        let overflow = accounts.count - visible.count
        HStack(spacing: -14) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { i, a in
                avatar(fill: Color(hex: a.colorHex), text: initials(a.name))
                    .opacity(highlight == nil || highlight == a.id ? 1 : 0.5)
                    .scaleEffect(highlight == a.id ? 1.12 : 1)
                    .zIndex(highlight == a.id ? 100 : Double(max - i))
            }
            if overflow > 0 {
                avatar(fill: Color(white: 0.22), text: "+\(overflow)")
                    .contentTransition(.numericText())
                    .zIndex(0)
            }
        }
        .animation(.bouncy(duration: 0.4), value: highlight)
    }

    private func avatar(fill: Color, text: String) -> some View {
        Circle().fill(fill)
            .frame(width: size, height: size)
            .overlay(Text(text).font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1))
            .overlay(Circle().strokeBorder(Color(hex: "#FFF8EC"), lineWidth: 2.5))
    }

    private func initials(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 { return (String(words[0].prefix(1)) + words[1].prefix(1)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }
}

/// Warm, light "honey ember" backdrop whose amber glows drift continuously.
/// Driven by TimelineView(.animation), so it animates forever without a trigger.
private struct HoneyEmberBackground: View {
    private struct Ember { let color: Color; let base: CGPoint; let amp: CGSize
                           let speed: Double; let phase: Double; let radius: CGFloat }
    private let embers: [Ember] = [
        .init(color: Color(hex: "#FBBF24"), base: .init(x: 0.25, y: 0.20), amp: .init(width: 0.12, height: 0.08), speed: 0.16, phase: 0.0, radius: 360),
        .init(color: Color(hex: "#F59E0B"), base: .init(x: 0.80, y: 0.30), amp: .init(width: 0.10, height: 0.10), speed: 0.12, phase: 1.7, radius: 340),
        .init(color: Color(hex: "#FB923C"), base: .init(x: 0.55, y: 0.75), amp: .init(width: 0.14, height: 0.10), speed: 0.20, phase: 3.1, radius: 320),
        .init(color: Color(hex: "#FDE68A"), base: .init(x: 0.15, y: 0.85), amp: .init(width: 0.10, height: 0.12), speed: 0.14, phase: 4.6, radius: 300),
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(colors: [Color(hex: "#FFF8EC"), Color(hex: "#FDEBCF")],
                               startPoint: .top, endPoint: .bottom)
                ForEach(embers.indices, id: \.self) { i in
                    let e = embers[i]
                    let x = e.base.x + e.amp.width * CGFloat(sin(t * e.speed + e.phase))
                    let y = e.base.y + e.amp.height * CGFloat(cos(t * e.speed * 0.9 + e.phase))
                    RadialGradient(colors: [e.color.opacity(0.5), e.color.opacity(0)],
                                   center: UnitPoint(x: x, y: y), startRadius: 0, endRadius: e.radius)
                        .blendMode(.multiply)
                }
            }
            .ignoresSafeArea()
        }
    }
}

/// Axis-free mini balance curve for the card: smooth monotone line, faint area
/// fill, and a dot on the latest point.
private struct BalanceChart: View {
    let series: [BalancePoint]
    let tint: Color
    var compact = true

    var body: some View {
        Chart {
            ForEach(series) { p in
                AreaMark(x: .value("Date", p.date), y: .value("Balance", p.doubleValue))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.02)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", p.date), y: .value("Balance", p.doubleValue))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            if let end = series.last {
                PointMark(x: .value("Date", end.date), y: .value("Balance", end.doubleValue))
                    .foregroundStyle(tint).symbolSize(70)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}
