import SwiftUI
import PhotosUI

/// Add / rename / recolor / delete accounts. Built-ins can't be deleted.
struct AccountManagerView: View {
    @Binding var accounts: [Account]

    @State private var editing: Account?

    private let colors = categoryColors

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
        .font(.system(.body, design: .rounded))
        .scrollContentBackground(.hidden)
        .background(GrainientBackground())
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
            AccountAvatar(account: a, size: 28)
            Text(a.name.isEmpty ? "(unnamed)" : a.name)
            Spacer()
            if a.builtin { Text("built-in").foregroundStyle(Color.appInk.opacity(0.6)).font(.caption) }
        }
    }

    /// Any account can be deleted now, built-in or not.
    private func delete(_ offsets: IndexSet) {
        let ids = offsets.map { accounts[$0].id }
        accounts.removeAll { ids.contains($0.id) }
    }
}

private struct AccountEditSheet: View {
    @State var account: Account
    let colors: [String]
    let onSave: (Account) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $account.name)
                Section("Image") {
                    HStack(spacing: 14) {
                        AccountAvatar(account: account, size: 52)
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label(account.photoFile == nil ? "Choose image" : "Replace image",
                                  systemImage: "photo")
                        }
                        if account.photoFile != nil {
                            Spacer()
                            Button(role: .destructive) { removePhoto() } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
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
            .font(.system(.body, design: .rounded))
            .scrollContentBackground(.hidden)
            .background(GrainientBackground())
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
        .onChange(of: pickerItem) { _, item in loadPhoto(item) }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let name = PhotoStore.save(data) {
                if let old = account.photoFile { PhotoStore.delete(old) }
                account.photoFile = name
            }
        }
    }

    private func removePhoto() {
        if let old = account.photoFile { PhotoStore.delete(old) }
        account.photoFile = nil
        pickerItem = nil
    }
}

/// An account's avatar: its custom photo if set, else a colored disc with the
/// name's initials. Shared by the switcher stack, the manager, and the editor.
struct AccountAvatar: View {
    let account: Account
    var size: CGFloat = 40
    var stroke: Color = .white.opacity(0.85)

    var body: some View {
        Group {
            if let file = account.photoFile, let ui = PhotoStore.load(file) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Color(hex: account.colorHex)
                    .overlay(Text(initials(account.name))
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appInk).minimumScaleFactor(0.6).lineLimit(1))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(stroke, lineWidth: size > 20 ? 2.5 : 1))
    }

    private func initials(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 { return (String(words[0].prefix(1)) + words[1].prefix(1)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }
}
