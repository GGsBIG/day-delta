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
}

extension Category {
    /// Seeded on first launch. IDs are per-process stable (a `static let`), then
    /// persisted by `CategoryStore.load()`, so they stay fixed after first run.
    static let builtins: [Category] = [
        .init(name: "Food", type: .expense, icon: nil, colorHex: "#4F9DFF", builtin: true),
        .init(name: "Transport", type: .expense, icon: nil, colorHex: "#A855F7", builtin: true),
        .init(name: "Shopping", type: .expense, icon: nil, colorHex: "#F59E0B", builtin: true),
        .init(name: "Entertainment", type: .expense, icon: nil, colorHex: "#22C55E", builtin: true),
        .init(name: "Housing", type: .expense, icon: nil, colorHex: "#EF4444", builtin: true),
        .init(name: "Health", type: .expense, icon: nil, colorHex: "#14B8A6", builtin: true),
        .init(name: "Other", type: .expense, icon: nil, colorHex: "#9CA3AF", builtin: true),
        .init(name: "Salary", type: .income, icon: nil, colorHex: "#22C55E", builtin: true),
        .init(name: "Bonus", type: .income, icon: nil, colorHex: "#4F9DFF", builtin: true),
        .init(name: "Investment", type: .income, icon: nil, colorHex: "#F59E0B", builtin: true),
        .init(name: "Other", type: .income, icon: nil, colorHex: "#9CA3AF", builtin: true),
    ]
}

enum TxnStore {
    private static let key = "daydelta.txns"

    static func load() -> [Txn] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let txns = try? JSONDecoder().decode([Txn].self, from: data)
        else { return [] }
        return txns
    }

    static func save(_ txns: [Txn]) {
        guard let data = try? JSONEncoder().encode(txns) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

enum CategoryStore {
    private static let key = "daydelta.categories"

    /// Returns stored categories, seeding the built-ins on first run.
    static func load() -> [Category] {
        if let data = UserDefaults.standard.data(forKey: key),
           let cats = try? JSONDecoder().decode([Category].self, from: data),
           !cats.isEmpty {
            return cats
        }
        save(Category.builtins)
        return Category.builtins
    }

    static func save(_ cats: [Category]) {
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
