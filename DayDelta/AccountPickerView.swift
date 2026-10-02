import SwiftUI

/// Pushed account chooser. Tapping a row sets the selection and pops back.
struct AccountPickerView: View {
    let accounts: [Account]
    @Binding var selection: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(accounts) { a in
                Button {
                    selection = a.id
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: a.colorHex)).frame(width: 12, height: 12)
                        Text(a.name)
                        Spacer()
                        if selection == a.id { Image(systemName: "checkmark").foregroundStyle(.white) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.black)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(.white)
        .navigationTitle("Account")
    }
}
