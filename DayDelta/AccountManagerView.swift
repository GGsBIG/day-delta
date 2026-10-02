import SwiftUI

/// Add / rename / recolor / delete accounts. Built-ins can't be deleted.
struct AccountManagerView: View {
    @Binding var accounts: [Account]

    @State private var editing: Account?

    private let colors = ["#4F9DFF", "#A855F7", "#F59E0B", "#22C55E",
                          "#EF4444", "#14B8A6", "#EC4899", "#9CA3AF"]

    var body: some View {
        List {
            ForEach(accounts) { a in
                Button { editing = a } label: { row(a) }
                    .buttonStyle(.plain)
            }
            .onDelete { offsets in delete(offsets) }
            Button {
                editing = Account(name: "", colorHex: colors[0])
            } label: {
                Label("Add account", systemImage: "plus")
            }
        }
        .font(.system(.body, design: .monospaced))
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Accounts")
        .sheet(item: $editing) { a in
            AccountEditSheet(account: a, colors: colors) { saved in
                if let i = accounts.firstIndex(where: { $0.id == saved.id }) {
                    accounts[i] = saved
                } else {
                    accounts.append(saved)
                }
                editing = nil
            }
        }
    }

    private func row(_ a: Account) -> some View {
        HStack {
            Circle().fill(Color(hex: a.colorHex)).frame(width: 14, height: 14)
            Text(a.name.isEmpty ? "(unnamed)" : a.name)
            Spacer()
            if a.builtin { Text("built-in").foregroundStyle(.gray).font(.caption) }
        }
    }

    /// Only non-builtin accounts delete; builtins silently skip.
    private func delete(_ offsets: IndexSet) {
        let ids = offsets.map { accounts[$0] }.filter { !$0.builtin }.map { $0.id }
        accounts.removeAll { ids.contains($0.id) }
    }
}

private struct AccountEditSheet: View {
    @State var account: Account
    let colors: [String]
    let onSave: (Account) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $account.name)
                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().strokeBorder(
                                    account.colorHex == hex ? Color.white : .clear, lineWidth: 2))
                                .onTapGesture { account.colorHex = hex }
                        }
                    }
                }
            }
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(account.name.isEmpty ? "New account" : account.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let n = account.name.trimmingCharacters(in: .whitespaces)
                        guard !n.isEmpty else { return }
                        account.name = n
                        onSave(account)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}
