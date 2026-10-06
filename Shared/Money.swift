import Foundation

enum TxnType: String, Codable, CaseIterable {
    case expense
    case income
}

/// One ledger entry. Money is `Decimal` — never `Double` — so sums don't drift.
struct Txn: Codable, Identifiable, Hashable {
    var id = UUID()
    var type: TxnType
    var amount: Decimal
    var categoryID: UUID
    var date: Date
    var note: String?
    var eventID: UUID?        // optional link to a countdown Event
    var accountID: UUID?      // optional payment account; nil for legacy rows
}

/// A spending/earning bucket. `builtin` categories can be renamed/recolored but
/// not deleted.
struct Category: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var type: TxnType
    var icon: String?         // asset name, reuses eventIconNames
    var colorHex: String      // "#RRGGBB", drives the donut
    var builtin: Bool = false
    /// Money moved into an investment/savings bucket (e.g. buying stocks). These
    /// expenses are excluded from "spending", so they count as saved, not spent.
    var isInvestment: Bool = false
}

extension Category {
    /// Seeded on first launch. IDs are per-process stable (a `static let`), then
    /// persisted by `CategoryStore.load()`, so they stay fixed after first run.
    static let builtins: [Category] = [
        .init(name: "Food", type: .expense, icon: "fork.knife", colorHex: "#4F9DFF", builtin: true),
        .init(name: "Transport", type: .expense, icon: "car.fill", colorHex: "#A855F7", builtin: true),
        .init(name: "Shopping", type: .expense, icon: "bag.fill", colorHex: "#F59E0B", builtin: true),
        .init(name: "Entertainment", type: .expense, icon: "gamecontroller.fill", colorHex: "#22C55E", builtin: true),
        .init(name: "Housing", type: .expense, icon: "house.fill", colorHex: "#EF4444", builtin: true),
        .init(name: "Health", type: .expense, icon: "cross.case.fill", colorHex: "#14B8A6", builtin: true),
        .init(name: "Other", type: .expense, icon: "ellipsis.circle.fill", colorHex: "#9CA3AF", builtin: true),
        .init(name: "Salary", type: .income, icon: "dollarsign.circle.fill", colorHex: "#22C55E", builtin: true),
        .init(name: "Bonus", type: .income, icon: "gift.fill", colorHex: "#4F9DFF", builtin: true),
        .init(name: "Investment", type: .income, icon: "chart.line.uptrend.xyaxis", colorHex: "#F59E0B", builtin: true),
        .init(name: "Other", type: .income, icon: "ellipsis.circle.fill", colorHex: "#9CA3AF", builtin: true),
    ]
}

/// A payment account/method (Cash, Bank, …). Builtins can be renamed/recolored
/// but not deleted. Mirrors Category, minus the type split.
struct Account: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var colorHex: String
    var builtin: Bool = false
    /// Optional custom avatar image (PhotoStore filename). nil = colored initials.
    var photoFile: String? = nil
}

extension Account {
    /// Seeded on first run. Just Cash + Bank; "All accounts" is the aggregate view,
    /// not a stored account. All accounts (these included) can be renamed/deleted.
    static let builtins: [Account] = [
        .init(name: "Cash", colorHex: "#22C55E"),
        .init(name: "Bank", colorHex: "#4F9DFF"),
    ]
}

enum AccountStore {
    private static let key = "daydelta.accounts"
    // ponytail: in-memory cache so tab switches reuse the decoded array instead
    // of decoding JSON from UserDefaults each time. Single process, main thread.
    private static var cache: [Account]?

    static func load() -> [Account] {
        if let cache { return cache }
        if let data = UserDefaults.standard.data(forKey: key),
           let accs = try? JSONDecoder().decode([Account].self, from: data),
           !accs.isEmpty {
            cache = accs
            return accs
        }
        save(Account.builtins)
        return Account.builtins
    }

    static func save(_ accs: [Account]) {
        cache = accs
        guard let data = try? JSONEncoder().encode(accs) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - Investments

/// One investment holding. `currentPrice` can be refreshed from live quotes when
/// a `symbol` is set, else entered by hand.
struct Holding: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: String          // instrument kind name, e.g. "US Stocks"
    var name: String          // display label, e.g. "Apple"
    var symbol: String = ""   // ticker for live quotes, e.g. "AAPL", "2330.TW"
    var quantity: Decimal
    var costPerUnit: Decimal
    var currentPrice: Decimal
    var date: Date = .now
    var note: String?
    var accountID: UUID? = nil // funding account for the linked purchase txn
    var txnID: UUID? = nil     // linked investment expense txn (keeps saved in sync)
}

extension Holding {
    var cost: Decimal { quantity * costPerUnit }
    var marketValue: Decimal { quantity * currentPrice }
    /// Unrealized profit/loss: market value minus cost.
    var gain: Decimal { marketValue - cost }
}

/// Built-in instrument kinds offered in the picker: (name, color, SF Symbol).
let investmentKinds: [(name: String, colorHex: String, icon: String)] = [
    ("US Stocks", "#4F9DFF", "chart.line.uptrend.xyaxis"),
    ("TW Stocks", "#EF4444", "chart.bar.fill"),
    ("Gold",      "#F59E0B", "circle.hexagongrid.fill"),
    ("Crypto",    "#A855F7", "bitcoinsign.circle.fill"),
    ("ETF",       "#22C55E", "chart.pie.fill"),
    ("Fund",      "#14B8A6", "building.columns.fill"),
    ("Bond",      "#EC4899", "doc.text.fill"),
    ("Cash",      "#9CA3AF", "banknote.fill"),
    ("Other",     "#9CA3AF", "ellipsis.circle.fill"),
]

func kindColorHex(_ name: String) -> String { investmentKinds.first { $0.name == name }?.colorHex ?? "#9CA3AF" }
func kindIcon(_ name: String) -> String { investmentKinds.first { $0.name == name }?.icon ?? "ellipsis.circle.fill" }

enum HoldingStore {
    private static let key = "daydelta.holdings"
    private static var cache: [Holding]?

    static func load() -> [Holding] {
        if let cache { return cache }
        let items = (UserDefaults.standard.data(forKey: key))
            .flatMap { try? JSONDecoder().decode([Holding].self, from: $0) } ?? []
        cache = items
        return items
    }

    static func save(_ items: [Holding]) {
        cache = items
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// Pulls `chart.result[0].meta.regularMarketPrice` out of the Yahoo Finance v8
/// chart JSON. Pure (no network) so it's unit-testable.
func parseQuotePrice(_ data: Data) -> Decimal? {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let chart = root["chart"] as? [String: Any],
          let results = chart["result"] as? [[String: Any]],
          let meta = results.first?["meta"] as? [String: Any],
          let price = meta["regularMarketPrice"] as? Double
    else { return nil }
    return Decimal(price)
}

enum TxnStore {
    private static let key = "daydelta.txns"
    private static var cache: [Txn]?

    static func load() -> [Txn] {
        if let cache { return cache }
        let txns = (UserDefaults.standard.data(forKey: key))
            .flatMap { try? JSONDecoder().decode([Txn].self, from: $0) } ?? []
        cache = txns
        return txns
    }

    static func save(_ txns: [Txn]) {
        cache = txns
        guard let data = try? JSONEncoder().encode(txns) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// Renames legacy Chinese built-in category names to English. Names that aren't
/// in the map (already English, or custom) are left untouched; id/type/color kept.
func migrateCategoryNames(_ cats: [Category]) -> [Category] {
    let map = ["餐飲": "Food", "交通": "Transport", "購物": "Shopping",
               "娛樂": "Entertainment", "居住": "Housing", "醫療": "Health",
               "其他": "Other", "薪資": "Salary", "獎金": "Bonus", "投資": "Investment"]
    return cats.map { c in
        guard let english = map[c.name] else { return c }
        var m = c
        m.name = english
        return m
    }
}

enum CategoryStore {
    private static let key = "daydelta.categories"
    private static var cache: [Category]?

    /// Returns stored categories, seeding the built-ins on first run.
    static func load() -> [Category] {
        if let cache { return cache }
        if let data = UserDefaults.standard.data(forKey: key),
           let cats = try? JSONDecoder().decode([Category].self, from: data),
           !cats.isEmpty {
            let migrated = migrateCategoryNames(cats)
            if migrated != cats { save(migrated) }   // one-time: persist English names
            cache = migrated
            return migrated
        }
        save(Category.builtins)
        return Category.builtins
    }

    static func save(_ cats: [Category]) {
        cache = cats
        guard let data = try? JSONEncoder().encode(cats) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// The expense category used for investment purchases (so they count as saved,
/// not spent). Returns the first investment-flagged expense category, creating a
/// persisted "Investments" one if none exists.
func ensureInvestmentCategory() -> Category {
    var cats = CategoryStore.load()
    if let c = cats.first(where: { $0.type == .expense && $0.isInvestment }) { return c }
    let c = Category(name: "Investments", type: .expense, icon: "chart.line.uptrend.xyaxis",
                     colorHex: "#A855F7", isInvestment: true)
    cats.append(c)
    CategoryStore.save(cats)
    return c
}

// MARK: - Stats

enum StatPeriod: String, CaseIterable {
    case week, month, year

    var granularity: Calendar.Component {
        switch self {
        case .week:  return .weekOfYear
        case .month: return .month
        case .year:  return .year
        }
    }

    var label: String {
        switch self {
        case .week:  return "Week"
        case .month: return "Month"
        case .year:  return "Year"
        }
    }
}

/// Txns falling in the same week/month/year as `ref`.
func txnsInPeriod(_ all: [Txn], period: StatPeriod, containing ref: Date,
                  calendar: Calendar = .current) -> [Txn] {
    all.filter { calendar.isDate($0.date, equalTo: ref, toGranularity: period.granularity) }
}

/// Total per category for one txn type, highest first.
func categoryTotals(_ txns: [Txn], type: TxnType) -> [(categoryID: UUID, total: Decimal)] {
    var sums: [UUID: Decimal] = [:]
    for t in txns where t.type == type {
        sums[t.categoryID, default: 0] += t.amount
    }
    return sums.map { (categoryID: $0.key, total: $0.value) }
        .sorted { $0.total > $1.total }
}


/// Locale-formatted currency string, e.g. "NT$150.00".
func formatMoney(_ amount: Decimal) -> String {
    let code = Locale.current.currency?.identifier ?? "USD"
    return amount.formatted(.currency(code: code))
}

// MARK: - Calendar

/// Start-of-day Date for every day in the month containing `ref`.
func daysInMonth(containing ref: Date, calendar: Calendar = .current) -> [Date] {
    guard let range = calendar.range(of: .day, in: .month, for: ref),
          let first = calendar.date(from: calendar.dateComponents([.year, .month], from: ref))
    else { return [] }
    return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: first) }
}

/// Number of empty leading cells before day 1, honoring `calendar.firstWeekday`.
func leadingBlanks(forMonthContaining ref: Date, calendar: Calendar = .current) -> Int {
    guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: ref))
    else { return 0 }
    let weekday = calendar.component(.weekday, from: first)
    return (weekday - calendar.firstWeekday + 7) % 7
}

/// Txns whose date is the same calendar day as `day`.
func txnsOn(_ all: [Txn], day: Date, calendar: Calendar = .current) -> [Txn] {
    all.filter { calendar.isDate($0.date, inSameDayAs: day) }
}

/// Category id of the single largest-amount txn (for the day's dot color).
func dominantCategoryID(_ txns: [Txn]) -> UUID? {
    txns.max { $0.amount < $1.amount }?.categoryID
}

/// `ref` shifted by `months`, normalized to start of day.
func addMonths(_ months: Int, to ref: Date, calendar: Calendar = .current) -> Date {
    let d = calendar.date(byAdding: .month, value: months, to: ref) ?? ref
    return calendar.startOfDay(for: d)
}

// MARK: - Amount keypad

enum AmountKey: Equatable {
    case digit(Int)
    case dot
    case delete
}

/// Pure edit of the amount string for the custom keypad. Enforces a single
/// decimal point and at most two fractional digits; a typed digit replaces a
/// lone leading "0". Delete removes the last character.
func applyAmountKey(_ s: String, _ key: AmountKey) -> String {
    switch key {
    case .delete:
        return String(s.dropLast())
    case .dot:
        if s.contains(".") { return s }
        return s.isEmpty ? "0." : s + "."
    case .digit(let d):
        if let dot = s.firstIndex(of: ".") {
            let decimals = s.distance(from: s.index(after: dot), to: s.endIndex)
            if decimals >= 2 { return s }
        }
        if s == "0" { return "\(d)" }
        return s + "\(d)"
    }
}

/// Net balance for one account: its income minus its expense. Pass nil for the
/// "unassigned" bucket (transactions with no account).
func accountBalance(_ txns: [Txn], accountID: UUID?) -> Decimal {
    txns.filter { $0.accountID == accountID }.reduce(Decimal(0)) {
        $0 + ($1.type == .income ? $1.amount : -$1.amount)
    }
}

/// One sample on the running-balance curve.
struct BalancePoint: Identifiable, Hashable {
    let date: Date
    let balance: Decimal
    var id: Date { date }
    var doubleValue: Double { NSDecimalNumber(decimal: balance).doubleValue }
}

/// Running balance sampled across the period. `scope` nil = every account (grand
/// total); otherwise just that account. Week/month sample daily, year monthly;
/// each point is the cumulative balance of every txn on or before that day.
/// ponytail: recomputes the full cumulative per bucket (O(points·txns)); fine for
/// a personal ledger, sort-and-scan if it ever grows large.
func balanceSeries(_ txns: [Txn], scope: UUID?, period: StatPeriod,
                   now: Date = .now, calendar: Calendar = .current) -> [BalancePoint] {
    let scoped = scope == nil ? txns : txns.filter { $0.accountID == scope }
    let signed = scoped.map { (date: $0.date, amount: $0.type == .income ? $0.amount : -$0.amount) }
    let today = calendar.startOfDay(for: now)

    let (count, component): (Int, Calendar.Component) = {
        switch period {
        case .week:  return (7, .day)
        case .month: return (30, .day)
        case .year:  return (12, .month)
        }
    }()

    return (0..<count).reversed().compactMap { back -> BalancePoint? in
        guard let bucket = calendar.date(byAdding: component, value: -back, to: today) else { return nil }
        let start = calendar.startOfDay(for: bucket)
        guard let cutoff = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let bal = signed.filter { $0.date < cutoff }.reduce(Decimal(0)) { $0 + $1.amount }
        return BalancePoint(date: start, balance: bal)
    }
}
