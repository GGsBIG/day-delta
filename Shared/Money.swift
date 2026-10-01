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
    var colorHex: String      // "#RRGGBB", drives donut/waffle
    var builtin: Bool = false
}

extension Category {
    /// Seeded on first launch. IDs are per-process stable (a `static let`), then
    /// persisted by `CategoryStore.load()`, so they stay fixed after first run.
    static let builtins: [Category] = [
        .init(name: "餐飲", type: .expense, icon: nil, colorHex: "#4F9DFF", builtin: true),
        .init(name: "交通", type: .expense, icon: nil, colorHex: "#A855F7", builtin: true),
        .init(name: "購物", type: .expense, icon: nil, colorHex: "#F59E0B", builtin: true),
        .init(name: "娛樂", type: .expense, icon: nil, colorHex: "#22C55E", builtin: true),
        .init(name: "居住", type: .expense, icon: nil, colorHex: "#EF4444", builtin: true),
        .init(name: "醫療", type: .expense, icon: nil, colorHex: "#14B8A6", builtin: true),
        .init(name: "其他", type: .expense, icon: nil, colorHex: "#9CA3AF", builtin: true),
        .init(name: "薪資", type: .income, icon: nil, colorHex: "#22C55E", builtin: true),
        .init(name: "獎金", type: .income, icon: nil, colorHex: "#4F9DFF", builtin: true),
        .init(name: "投資", type: .income, icon: nil, colorHex: "#F59E0B", builtin: true),
        .init(name: "其他", type: .income, icon: nil, colorHex: "#9CA3AF", builtin: true),
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

/// Distribute `cells` across `totals` by proportion using largest-remainder, so
/// the result always sums to exactly `cells`. Aligned to the input order.
func waffleCounts(_ totals: [Decimal], cells: Int = 100) -> [Int] {
    let sum = totals.reduce(0, +)
    guard sum > 0 else { return totals.map { _ in 0 } }
    let raw = totals.map { NSDecimalNumber(decimal: $0 / sum).doubleValue * Double(cells) }
    var floors = raw.map { Int($0) }
    var remainder = cells - floors.reduce(0, +)
    let order = raw.enumerated()
        .sorted { ($0.element - Double(Int($0.element))) > ($1.element - Double(Int($1.element))) }
        .map { $0.offset }
    var i = 0
    while remainder > 0, i < order.count {
        floors[order[i]] += 1
        remainder -= 1
        i += 1
    }
    return floors
}

/// Locale-formatted currency string, e.g. "NT$150.00".
func formatMoney(_ amount: Decimal) -> String {
    let code = Locale.current.currency?.identifier ?? "USD"
    return amount.formatted(.currency(code: code))
}
