import SwiftUI

/// Custom numeric keypad that edits an amount string via `applyAmountKey`.
struct Keypad: View {
    @Binding var amount: String

    private let rows: [[AmountKey]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.dot, .digit(0), .delete],
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                        keyButton(key)
                    }
                }
            }
        }
        .padding(12)
    }

    private func keyButton(_ key: AmountKey) -> some View {
        Button {
            amount = applyAmountKey(amount, key)
        } label: {
            Text(label(key))
                .font(.system(.title2, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12)))
        }
        .buttonStyle(.plain)
    }

    private func label(_ key: AmountKey) -> String {
        switch key {
        case .digit(let d): return "\(d)"
        case .dot: return "."
        case .delete: return "⌫"
        }
    }
}
