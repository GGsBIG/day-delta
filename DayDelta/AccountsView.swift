import SwiftUI

/// Accounts overview: total balance on top, then each account's balance.
/// The whole view rides the tab container's slide-in — no per-row stagger.
struct AccountsView: View {
    @State private var txns: [Txn] = TxnStore.load()
    @State private var accounts: [Account] = AccountStore.load()

    private var total: Decimal {
        txns.reduce(Decimal(0)) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
    }

    private var hasUnassigned: Bool { txns.contains { $0.accountID == nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("Total balance").font(.caption).foregroundStyle(.gray)
                        Text(formatMoney(total))
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.4).lineLimit(1)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 10) {
                        ForEach(Array(accounts.enumerated()), id: \.element.id) { i, a in
                            balanceRow(name: a.name, color: Color(hex: a.colorHex),
                                       value: accountBalance(txns, accountID: a.id))
                        }
                        if hasUnassigned {
                            balanceRow(name: "Unassigned", color: .gray,
                                       value: accountBalance(txns, accountID: nil))
                        }
                    }
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Accounts")
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .onAppear {
            txns = TxnStore.load()
            accounts = AccountStore.load()
        }
    }

    private func balanceRow(name: String, color: Color, value: Decimal) -> some View {
        HStack {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(name)
            Spacer()
            Text(formatMoney(value))
                .foregroundStyle(value < 0 ? .red : .green)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.1)))
    }
}
