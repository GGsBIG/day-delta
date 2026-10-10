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
    var transferID: UUID?     // links the two legs of an account transfer
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
    /// Internal category for account transfers; excluded from income/expense stats.
    var isTransfer: Bool = false
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
    var quantity: Decimal      // total shares (lots are expanded to shares)
    var costPerUnit: Decimal
    var currentPrice: Decimal
    var date: Date = .now
    var note: String?
    var accountID: UUID? = nil // funding account for the linked purchase txn
    var txnID: UUID? = nil     // linked investment expense txn (keeps saved in sync)
    var wholeLot: Bool = false // bought in whole lots (×1000 shares) vs odd lots
}

/// Same-symbol purchases merged for display. Totals sum the individual lots.
struct HoldingGroup: Identifiable {
    let key: String
    let lots: [Holding]
    var id: String { key }
    var kind: String { lots.first?.kind ?? "" }
    var name: String { lots.first?.name ?? "" }
    var symbol: String { lots.first?.symbol ?? "" }
    var currentPrice: Decimal { lots.last?.currentPrice ?? 0 }
    var shares: Decimal { lots.reduce(0) { $0 + $1.quantity } }
    var cost: Decimal { lots.reduce(0) { $0 + $1.cost } }
    var marketValue: Decimal { lots.reduce(0) { $0 + $1.marketValue } }
    var gain: Decimal { lots.reduce(0) { $0 + $1.gain } }
}

/// Groups holdings so repeated buys of the same stock collapse into one entry.
/// Key = symbol if set, else name, else the id (keeps distinct). First-seen order.
func groupHoldings(_ holdings: [Holding]) -> [HoldingGroup] {
    var order: [String] = []
    var map: [String: [Holding]] = [:]
    for h in holdings {
        let key = !h.symbol.isEmpty ? h.symbol : (!h.name.isEmpty ? h.name : h.id.uuidString)
        if map[key] == nil { order.append(key) }
        map[key, default: []].append(h)
    }
    return order.map { HoldingGroup(key: $0, lots: map[$0] ?? []) }
}

/// Grams per troy ounce and per Taiwan tael — for converting international gold
/// (USD/oz) to a local TWD-per-兩 price.
let gramsPerOunce: Decimal = 31.1035
let gramsPerTael: Decimal = 37.5

/// International gold (USD per ounce) × USD→TWD → TWD per 台兩. Pure.
func goldTWDPerTael(usdPerOz: Decimal, usdTwd: Decimal) -> Decimal {
    usdPerOz * usdTwd / gramsPerOunce * gramsPerTael
}

extension Holding {
    var cost: Decimal { quantity * costPerUnit }
    var marketValue: Decimal { quantity * currentPrice }
    /// Unrealized profit/loss: market value minus cost.
    var gain: Decimal { marketValue - cost }
}

/// Reduce a group's lots by `quantity` sold, FIFO (earliest purchase first).
/// Lots fully sold are dropped; a partially sold lot keeps its cost basis. Returns
/// the surviving lots in date order. Pure — the buy txns are left untouched.
func reduceLots(_ lots: [Holding], by quantity: Decimal) -> [Holding] {
    var remaining = quantity
    var kept: [Holding] = []
    for lot in lots.sorted(by: { $0.date < $1.date }) {
        if remaining <= 0 { kept.append(lot); continue }
        if lot.quantity <= remaining {
            remaining -= lot.quantity          // whole lot sold → dropped
        } else {
            var l = lot; l.quantity -= remaining; remaining = 0
            kept.append(l)
        }
    }
    return kept
}

/// Built-in instrument kinds offered in the picker: (name, color, SF Symbol).
let investmentKinds: [(name: String, colorHex: String, icon: String)] = [
    ("US Stocks", "#4F9DFF", "chart.line.uptrend.xyaxis"),
    ("TW Stocks", "#EF4444", "chart.bar.fill"),
    ("Gold",      "#F59E0B", "circle.hexagongrid.fill"),
]
let kindUSStocks = "US Stocks", kindTWStocks = "TW Stocks", kindGold = "Gold"

func kindColorHex(_ name: String) -> String { investmentKinds.first { $0.name == name }?.colorHex ?? "#9CA3AF" }
func kindIcon(_ name: String) -> String { investmentKinds.first { $0.name == name }?.icon ?? "ellipsis.circle.fill" }

/// Bundled pick-lists so users choose a ticker instead of searching. (symbol, name).
let usStocks: [(symbol: String, name: String)] = [
    ("AAPL","Apple"),("MSFT","Microsoft"),("NVDA","NVIDIA"),("GOOGL","Alphabet"),("AMZN","Amazon"),
    ("TSM","TSMC ADR"),("ASML","ASML"),("BABA","Alibaba"),("NIO","NIO"),("ARM","Arm Holdings"),
    ("SPCX","SPAC & New Issue ETF"),("RKLB","Rocket Lab"),("SPCE","Virgin Galactic"),("ARKX","ARK Space ETF"),
    ("CRCL","Circle Internet"),("COIN","Coinbase"),("HOOD","Robinhood"),("MSTR","MicroStrategy"),
    ("META","Meta Platforms"),("TSLA","Tesla"),("BRK-B","Berkshire Hathaway"),("AVGO","Broadcom"),("JPM","JPMorgan Chase"),
    ("V","Visa"),("MA","Mastercard"),("UNH","UnitedHealth"),("LLY","Eli Lilly"),("JNJ","Johnson & Johnson"),
    ("XOM","Exxon Mobil"),("WMT","Walmart"),("PG","Procter & Gamble"),("HD","Home Depot"),("COST","Costco"),
    ("ORCL","Oracle"),("MRK","Merck"),("ABBV","AbbVie"),("CVX","Chevron"),("PEP","PepsiCo"),
    ("KO","Coca-Cola"),("ADBE","Adobe"),("CRM","Salesforce"),("BAC","Bank of America"),("AMD","AMD"),
    ("NFLX","Netflix"),("TMO","Thermo Fisher"),("MCD","McDonald's"),("CSCO","Cisco"),("ACN","Accenture"),
    ("ABT","Abbott"),("DHR","Danaher"),("INTC","Intel"),("QCOM","Qualcomm"),("TXN","Texas Instruments"),
    ("DIS","Disney"),("WFC","Wells Fargo"),("VZ","Verizon"),("CMCSA","Comcast"),("PM","Philip Morris"),
    ("NKE","Nike"),("INTU","Intuit"),("IBM","IBM"),("AMAT","Applied Materials"),("GE","GE Aerospace"),
    ("CAT","Caterpillar"),("HON","Honeywell"),("UNP","Union Pacific"),("LOW","Lowe's"),("SPGI","S&P Global"),
    ("BA","Boeing"),("GS","Goldman Sachs"),("MS","Morgan Stanley"),("UBER","Uber"),("NOW","ServiceNow"),
    ("PLTR","Palantir"),("SBUX","Starbucks"),("PYPL","PayPal"),("T","AT&T"),("BKNG","Booking"),
    ("SPY","SPDR S&P 500 ETF"),("QQQ","Invesco QQQ"),("VOO","Vanguard S&P 500"),("VTI","Vanguard Total Market"),("SCHD","Schwab Dividend ETF"),
]
let twStocks: [(symbol: String, name: String)] = [
    ("2330.TW","台積電"),("2317.TW","鴻海"),("2454.TW","聯發科"),("2308.TW","台達電"),("2412.TW","中華電"),
    ("2881.TW","富邦金"),("2882.TW","國泰金"),("2303.TW","聯電"),("1303.TW","南亞"),("1301.TW","台塑"),
    ("2002.TW","中鋼"),("3008.TW","大立光"),("2886.TW","兆豐金"),("2891.TW","中信金"),("2884.TW","玉山金"),
    ("2885.TW","元大金"),("2892.TW","第一金"),("2880.TW","華南金"),("2883.TW","開發金"),("2890.TW","永豐金"),
    ("3045.TW","台灣大"),("4904.TW","遠傳"),("2207.TW","和泰車"),("2379.TW","瑞昱"),("3711.TW","日月光投控"),
    ("2357.TW","華碩"),("2382.TW","廣達"),("2395.TW","研華"),("2409.TW","友達"),("3034.TW","聯詠"),
    ("2327.TW","國巨"),("1216.TW","統一"),("1101.TW","台泥"),("2105.TW","正新"),("2912.TW","統一超"),
    ("5880.TW","合庫金"),("2801.TW","彰銀"),("2823.TW","中壽"),("6505.TW","台塑化"),("3037.TW","欣興"),
    ("2615.TW","萬海"),("2603.TW","長榮"),("2609.TW","陽明"),("2618.TW","長榮航"),("2610.TW","華航"),
    ("0050.TW","元大台灣50"),("0056.TW","元大高股息"),("00878.TW","國泰永續高股息"),("006208.TW","富邦台50"),("00929.TW","復華台灣科技優息"),
]

/// The pick-list for an instrument kind (empty for kinds with no bundled list).
func stockList(for kind: String) -> [(symbol: String, name: String)] {
    switch kind { case kindUSStocks: return usStocks; case kindTWStocks: return twStocks; default: return [] }
}

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

/// Pulls a daily (date, close) series from Yahoo v8 chart JSON, skipping nulls. Pure.
func parseChartSeries(_ data: Data) -> [(date: Date, close: Decimal)] {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let chart = root["chart"] as? [String: Any],
          let result = (chart["result"] as? [[String: Any]])?.first,
          let stamps = result["timestamp"] as? [Double],
          let indicators = result["indicators"] as? [String: Any],
          let closes = (indicators["quote"] as? [[String: Any]])?.first?["close"] as? [Double?]
    else { return [] }
    return zip(stamps, closes).compactMap { ts, c in
        guard let c else { return nil }
        return (Date(timeIntervalSince1970: ts), Decimal(c))
    }
}

/// One sample on the portfolio value curve.
struct PortfolioPoint: Identifiable, Hashable {
    let date: Date
    let value: Decimal
    var id: Date { date }
    var doubleValue: Double { NSDecimalNumber(decimal: value).doubleValue }
}

/// Daily portfolio market value over `days` ending at `endingAt`. For each day,
/// value = Σ holdings bought on/before that day × the symbol's as-of close.
/// `history` maps symbol → ascending (date, close). Pure.
func portfolioSeries(holdings: [Holding], history: [String: [(date: Date, close: Decimal)]],
                     days: Int, endingAt: Date, calendar: Calendar = .current) -> [PortfolioPoint] {
    let end = calendar.startOfDay(for: endingAt)
    func asOf(_ series: [(date: Date, close: Decimal)], _ day: Date) -> Decimal? {
        series.last { $0.date <= calendar.date(byAdding: .day, value: 1, to: day)! }?.close
    }
    return (0..<days).reversed().compactMap { back in
        guard let day = calendar.date(byAdding: .day, value: -back, to: end) else { return nil }
        var total: Decimal = 0
        for h in holdings where calendar.startOfDay(for: h.date) <= day {
            let key = h.kind == kindGold ? "GOLD" : h.symbol
            if let close = asOf(history[key] ?? [], day) { total += h.quantity * close }
        }
        return PortfolioPoint(date: day, value: total)
    }
}

/// Percent change from `prev` to `now` (0 when prev is 0).
func changePct(_ now: Decimal, _ prev: Decimal) -> Double {
    let p = (prev as NSDecimalNumber).doubleValue
    guard p != 0 else { return 0 }
    return ((now as NSDecimalNumber).doubleValue - p) / abs(p) * 100
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
    formatMoney(amount, code: Locale.current.currency?.identifier ?? "USD")
}

/// Currency string in a specific code (e.g. "USD" → "$", "TWD" → "NT$").
/// Whole amounts drop the trailing ".00"; cents show only when there are any.
func formatMoney(_ amount: Decimal, code: String) -> String {
    let n = NSDecimalNumber(decimal: amount)
    func round(_ scale: Int16) -> NSDecimalNumber {
        n.rounding(accordingToBehavior: NSDecimalNumberHandler(
            roundingMode: .plain, scale: scale, raiseOnExactness: false, raiseOnOverflow: false,
            raiseOnUnderflow: false, raiseOnDivideByZero: false))
    }
    let digits = round(2) == round(0) ? 0 : 2
    return amount.formatted(.currency(code: code).precision(.fractionLength(digits)))
}

// MARK: - Investment currency

/// A holding's market value in the display currency. In USD view it's as-is (the
/// filtered set is all US stocks); in TWD view, USD holdings are converted by `fx`.
func value(_ marketValue: Decimal, kind: String, displayUSD: Bool, fx: Decimal) -> Decimal {
    if displayUSD { return marketValue }
    return kind == kindUSStocks ? marketValue * fx : marketValue
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

/// A padded, never-zero-height Y range for a line/area chart. Flat or empty data
/// would otherwise give Swift Charts a zero-range scale — it divides by that and
/// floods "Invalid frame dimension (negative or non-finite)". Pure.
func chartYDomain(_ values: [Double]) -> ClosedRange<Double> {
    let lo = values.min() ?? 0, hi = values.max() ?? 1
    guard hi > lo else { return (lo - 1)...(lo + 1) }
    let pad = (hi - lo) * 0.1
    return (lo - pad)...(hi + pad)
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
