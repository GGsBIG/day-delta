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
