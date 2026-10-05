import SwiftUI
import Charts
import UIKit

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

    /// Background base color (shared with GrainientBackground via AppStorage).
    @AppStorage("accountsBgHex") private var bgHex = "#5227FF"
    private var bgColor: Binding<Color> {
        Binding(get: { Color(hex: bgHex) }, set: { bgHex = $0.toHex() })
    }

    private enum Palette {
        static let text = Color.white
        static let textSoft = Color.white.opacity(0.72)
        static let accent = Color(hex: "#FFCEFD")                           // grainient pink
        static let accent2 = Color(hex: "#5227FF")                          // grainient purple
        static let subcard = Color.white.opacity(0.1)
        static let stroke = Color.white.opacity(0.22)
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
            VStack(alignment: .leading, spacing: 16) {
                header
                balanceBlock
                chips
                card
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.snappy(duration: 0.45), value: balance)
            .animation(.snappy(duration: 0.45), value: period)
            .animation(.snappy(duration: 0.45), value: selected)
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

    // MARK: Header (greeting + switcher)

    private var header: some View {
        HStack(spacing: 12) {
            AvatarStack(accounts: accounts, highlight: selected)
            VStack(alignment: .leading, spacing: 1) {
                Text("Welcome back").font(.caption).foregroundStyle(Palette.textSoft.opacity(0.8))
                Text(selectedName).font(.system(.headline, design: .rounded)).fontWeight(.bold)
                    .foregroundStyle(Palette.text).lineLimit(1)
            }
            Spacer()
            ColorPicker("Background color", selection: bgColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 42, height: 42)
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
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().strokeBorder(Palette.stroke))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: selected)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: UI.radius).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: UI.radius).strokeBorder(Palette.stroke))
    }

    // MARK: Balance block

    private var balanceBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("Spend Account").font(.system(.title3, design: .rounded)).fontWeight(.bold)
                    .foregroundStyle(Palette.textSoft)
                Spacer()
            }
            Text(formatMoney(balance))
                .font(.system(size: 52, weight: .thin, design: .rounded)).tracking(-1.5)
                .foregroundStyle(Palette.text).minimumScaleFactor(0.4).lineLimit(1)
                .contentTransition(.numericText(value: (balance as NSDecimalNumber).doubleValue))
            HStack(spacing: 10) {
                Label(periodPct >= 0 ? "You've saved this \(period.label.lowercased())!"
                                     : "Spending up this \(period.label.lowercased())",
                      systemImage: "sparkles")
                    .font(.system(.subheadline, design: .rounded)).foregroundStyle(Palette.textSoft)
                    .labelStyle(.titleAndIcon)
                Text(String(format: "%+.2f%%", periodPct))
                    .font(.system(.caption, design: .rounded)).foregroundStyle(.white)
                    .padding(.vertical, 5).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: UI.radius).fill(LinearGradient(
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
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(on ? .white : Palette.text)
                        .padding(.vertical, 11).padding(.horizontal, 22)
                        .background(RoundedRectangle(cornerRadius: UI.radius).fill(on
                            ? AnyShapeStyle(LinearGradient(colors: [Palette.accent, Palette.accent2],
                                                           startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(.ultraThinMaterial)))
                        .overlay(RoundedRectangle(cornerRadius: UI.radius).strokeBorder(on ? .clear : Palette.stroke))
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
                    Text(periodTitle).font(.system(.title3, design: .rounded)).fontWeight(.bold).foregroundStyle(Palette.text)
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
                        .font(.system(.title, design: .rounded)).tracking(-0.8)
                        .foregroundStyle(Palette.text)
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
        .background(RoundedRectangle(cornerRadius: UI.radius).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: UI.radius).strokeBorder(Palette.stroke))
        .padding(.bottom, 4)
    }

    private func miniStat(_ title: String, _ value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(.subheadline, design: .rounded)).foregroundStyle(Palette.textSoft)
            Text(formatMoney(value)).font(.system(.title3, design: .rounded)).tracking(-0.5)
                .foregroundStyle(Palette.text).minimumScaleFactor(0.5).lineLimit(1)
                .contentTransition(.numericText(value: (value as NSDecimalNumber).doubleValue))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: UI.radius).fill(Palette.subcard))
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
                AccountAvatar(account: a, size: size)
                    .opacity(highlight == nil || highlight == a.id ? 1 : 0.5)
                    .scaleEffect(highlight == a.id ? 1.12 : 1)
                    .zIndex(highlight == a.id ? 100 : Double(max - i))
            }
            if overflow > 0 {
                Color(white: 0.22)
                    .frame(width: size, height: size)
                    .overlay(Text("+\(overflow)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1))
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2.5))
                    .contentTransition(.numericText())
                    .zIndex(0)
            }
        }
        .animation(.bouncy(duration: 0.4), value: highlight)
    }
}

/// Grainient backdrop: drifting pink→purple gradient blobs over a purple base,
/// finished with a film-grain overlay and boosted contrast. Animates forever via
/// TimelineView(.animation).
/// ponytail: gradient-blob approximation of the Grainient shader — the Metal
/// toolchain isn't installed here. Swap for a `.colorEffect` shader if it is.
struct GrainientBackground: View {
    /// Shared base color, chosen on the Accounts page. Every tab reads this key,
    /// so recoloring there recolors the whole app's backdrop.
    @AppStorage("accountsBgHex") private var bgHex = "#5227FF"

    private typealias Geo = (base: (Double, Double), amp: (Double, Double),
                             speed: Double, phase: Double, r: CGFloat, blend: BlendMode)
    private let geos: [Geo] = [
        ((0.30, 0.24), (0.18, 0.12), 0.22, 0.0, 520, .screen),
        ((0.76, 0.62), (0.16, 0.14), 0.17, 1.5, 480, .screen),
        ((0.50, 0.92), (0.20, 0.12), 0.20, 3.0, 440, .screen),
        ((0.20, 0.80), (0.14, 0.16), 0.15, 4.2, 420, .multiply),
    ]

    var body: some View {
        let p = palette(Color(hex: bgHex))
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(colors: [p.top, p.bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                ForEach(geos.indices, id: \.self) { i in
                    let g = geos[i]
                    let x = g.base.0 + g.amp.0 * sin(t * g.speed + g.phase)
                    let y = g.base.1 + g.amp.1 * cos(t * g.speed * 0.9 + g.phase)
                    RadialGradient(colors: [p.blobs[i], p.blobs[i].opacity(0)],
                                   center: UnitPoint(x: x, y: y), startRadius: 0, endRadius: g.r)
                        .blendMode(g.blend)
                }
            }
            .contrast(1.5)
            .overlay(GrainTexture.image.opacity(0.09).blendMode(.overlay))
            .ignoresSafeArea()
        }
    }

    /// Derive the base gradient + four blob colors from one chosen color by
    /// shifting hue/saturation/brightness around it.
    private func palette(_ base: Color) -> (top: Color, bottom: Color, blobs: [Color]) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(base).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let S = Double(s), B = Double(b)
        func c(_ dh: Double, _ sat: Double, _ bri: Double) -> Color {
            var hue = (Double(h) + dh / 360).truncatingRemainder(dividingBy: 1); if hue < 0 { hue += 1 }
            return Color(hue: hue, saturation: min(max(sat, 0), 1), brightness: min(max(bri, 0), 1))
        }
        return (
            top: c(0, S, max(0.28, B * 0.8)),
            bottom: c(-8, min(1, S + 0.1), max(0.12, B * 0.35)),
            blobs: [
                c(12, S * 0.45, 0.99),                      // light tint
                c(28, S * 0.8, min(1, B + 0.05)),           // hue-shifted
                c(0, S, B),                                 // the chosen color
                c(-18, min(1, S + 0.1), max(0.1, B * 0.3)), // deep shadow
            ]
        )
    }
}

private extension Color {
    /// "#RRGGBB" for persisting a chosen color. Pairs with `Color(hex:)`.
    func toHex() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }
}

/// A tiled static noise image for film grain, built once.
private enum GrainTexture {
    static let image: Image = {
        let n = 128, bytes = n * n * 4
        var px = [UInt8](repeating: 255, count: bytes)
        for i in 0..<(n * n) {
            let v = UInt8.random(in: 0...255)
            px[i * 4] = v; px[i * 4 + 1] = v; px[i * 4 + 2] = v
        }
        let ctx = CGContext(data: &px, width: n, height: n, bitsPerComponent: 8,
                            bytesPerRow: n * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let cg = ctx?.makeImage() else { return Image(systemName: "circle") }
        return Image(decorative: cg, scale: 1).resizable(resizingMode: .tile)
    }()
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
