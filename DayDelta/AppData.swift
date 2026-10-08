import Foundation
import Observation
import WidgetKit

/// Single source of truth for the money data, shared across the always-alive
/// paged tabs. Views read these arrays and mutate through here; `@Observable`
/// makes every page update live (no more "reopen the app to see the new total").
/// Each array auto-persists via `didSet` and refreshes the Home-Screen widgets.
@Observable final class AppData {
    static let shared = AppData()

    var txns: [Txn] { didSet { TxnStore.save(txns); reloadWidgets() } }
    var accounts: [Account] { didSet { AccountStore.save(accounts); reloadWidgets() } }
    var categories: [Category] { didSet { CategoryStore.save(categories) } }
    var holdings: [Holding] { didSet { HoldingStore.save(holdings); reloadWidgets() } }

    private func reloadWidgets() { WidgetCenter.shared.reloadAllTimelines() }

    private init() {
        txns = TxnStore.load()
        accounts = AccountStore.load()
        categories = CategoryStore.load()
        holdings = HoldingStore.load()
    }

    // MARK: Txns

    func addTxn(_ t: Txn) { txns.append(t) }
    func updateTxn(_ t: Txn) { if let i = txns.firstIndex(where: { $0.id == t.id }) { txns[i] = t } }
    /// Delete a txn; a transfer leg takes its paired leg with it.
    func deleteTxn(id: UUID) {
        if let tid = txns.first(where: { $0.id == id })?.transferID {
            txns.removeAll { $0.transferID == tid }
        } else {
            txns.removeAll { $0.id == id }
        }
    }

    // MARK: Transfers (between accounts)

    /// The internal category both transfer legs use. Created once if missing.
    private func transferCategoryID() -> UUID {
        if let c = categories.first(where: { $0.isTransfer }) { return c.id }
        let c = Category(name: "Transfer", type: .expense, icon: "arrow.left.arrow.right",
                         colorHex: "#9CA3AF", isTransfer: true)
        categories.append(c)
        return c.id
    }

    /// Move `amount` between accounts: an expense on `from` + income on `to`, linked
    /// by a shared transferID. Account balances change; the grand total nets to 0.
    func transfer(amount: Decimal, from: UUID?, to: UUID?, date: Date, note: String?) {
        let catID = transferCategoryID()
        let tid = UUID()
        txns.append(Txn(type: .expense, amount: amount, categoryID: catID, date: date,
                        note: note, accountID: from, transferID: tid))
        txns.append(Txn(type: .income, amount: amount, categoryID: catID, date: date,
                        note: note, accountID: to, transferID: tid))
    }

    /// Merge imported records (upsert by id). Used by backup import.
    func merge(txns t: [Txn], categories c: [Category], accounts a: [Account], holdings h: [Holding]) {
        func upsert<T: Identifiable>(_ items: inout [T], _ incoming: [T]) where T.ID == UUID {
            for x in incoming {
                if let i = items.firstIndex(where: { $0.id == x.id }) { items[i] = x } else { items.append(x) }
            }
        }
        upsert(&txns, t); upsert(&categories, c); upsert(&accounts, a); upsert(&holdings, h)
    }

    // MARK: Holdings (+ linked investment-expense txn)

    /// The expense category investment buys are logged under (so they count as
    /// saved, not spent). Created once if missing.
    private func investmentCategoryID() -> UUID {
        if let c = categories.first(where: { $0.type == .expense && $0.isInvestment }) { return c.id }
        let c = Category(name: "Investments", type: .expense, icon: "chart.line.uptrend.xyaxis",
                         colorHex: "#A855F7", isInvestment: true)
        categories.append(c)
        return c.id
    }

    /// Upsert a holding. Its cost is logged as an investment expense **only when a
    /// funding account is chosen** — unassigned buys stay out of the ledger / All
    /// Accounts. Editing to Unassigned removes any existing linked txn.
    func saveHolding(_ h: Holding) {
        var holding = h
        var next = txns
        if holding.accountID != nil {
            let catID = investmentCategoryID()
            if let tid = holding.txnID, let i = next.firstIndex(where: { $0.id == tid }) {
                next[i].amount = holding.cost; next[i].date = holding.date
                next[i].note = holding.name; next[i].accountID = holding.accountID; next[i].categoryID = catID
            } else {
                let t = Txn(type: .expense, amount: holding.cost, categoryID: catID,
                            date: holding.date, note: holding.name, accountID: holding.accountID)
                holding.txnID = t.id
                next.append(t)
            }
        } else if let tid = holding.txnID {
            next.removeAll { $0.id == tid }
            holding.txnID = nil
        }
        txns = next

        if let i = holdings.firstIndex(where: { $0.id == holding.id }) { holdings[i] = holding }
        else { holdings.append(holding) }
    }

    func deleteHoldings(ids: [UUID]) {
        let txnIDs = Set(holdings.filter { ids.contains($0.id) }.compactMap(\.txnID))
        if !txnIDs.isEmpty { txns.removeAll { txnIDs.contains($0.id) } }
        holdings.removeAll { ids.contains($0.id) }
    }
}
