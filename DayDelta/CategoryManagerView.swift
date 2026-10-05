import SwiftUI

/// Add / rename / recolor / delete categories. Built-ins can't be deleted.
struct CategoryManagerView: View {
    @Binding var categories: [Category]

    @State private var editing: Category?
    @State private var adding = false
    @State private var confirmingReset = false

    private let colors = ["#4F9DFF", "#A855F7", "#F59E0B", "#22C55E",
                          "#EF4444", "#14B8A6", "#EC4899", "#9CA3AF"]

    var body: some View {
        List {
            ForEach(TxnType.allCases, id: \.self) { type in
                Section(type == .expense ? "Expense" : "Income") {
                    ForEach(categories.filter { $0.type == type }) { c in
                        Button { editing = c } label: { row(c) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in delete(type: type, offsets: offsets) }
                    Button {
                        editing = Category(name: "", type: type, icon: nil,
                                           colorHex: colors[0])
                        adding = true
                    } label: {
                        Label("Add category", systemImage: "plus")
                    }
                }
            }
            Section {
                Button(role: .destructive) { confirmingReset = true } label: {
                    Label("Reset to default categories", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .font(.system(.body, design: .rounded))
        .scrollContentBackground(.hidden)
        .background(GrainientBackground())
        .navigationTitle("Categories")
        .sheet(item: $editing) { c in
            editSheet(c)
        }
        .confirmationDialog("Reset categories?", isPresented: $confirmingReset,
                            titleVisibility: .visible) {
            Button("Reset to defaults", role: .destructive) {
                categories = Category.builtins
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Replaces all categories with the English defaults. Custom categories are removed.")
        }
    }

    private func row(_ c: Category) -> some View {
        HStack {
            Circle().fill(Color(hex: c.colorHex)).frame(width: 14, height: 14)
            Text(c.name.isEmpty ? "(unnamed)" : c.name)
            Spacer()
            if c.builtin { Text("built-in").foregroundStyle(.gray).font(.caption) }
        }
    }

    @ViewBuilder
    private func editSheet(_ original: Category) -> some View {
        CategoryEditSheet(category: original, colors: colors) { saved in
            if let i = categories.firstIndex(where: { $0.id == saved.id }) {
                categories[i] = saved
            } else {
                categories.append(saved)
            }
            editing = nil
            adding = false
        }
    }

    /// Only non-builtin categories delete; builtins silently skip.
    private func delete(type: TxnType, offsets: IndexSet) {
        let inType = categories.filter { $0.type == type }
        let ids = offsets.map { inType[$0] }.filter { !$0.builtin }.map { $0.id }
        categories.removeAll { ids.contains($0.id) }
    }
}

/// The per-category editor (name + color).
private struct CategoryEditSheet: View {
    @State var category: Category
    let colors: [String]
    let onSave: (Category) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $category.name)
                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().strokeBorder(
                                    category.colorHex == hex ? Color.white : .clear, lineWidth: 2))
                                .onTapGesture { category.colorHex = hex }
                        }
                    }
                }
                Section("Icon") { IconPicker(selection: $category.icon) }
            }
            .font(.system(.body, design: .rounded))
            .scrollContentBackground(.hidden)
            .background(GrainientBackground())
            .navigationTitle(category.name.isEmpty ? "New category" : category.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let n = category.name.trimmingCharacters(in: .whitespaces)
                        guard !n.isEmpty else { return }
                        category.name = n
                        onSave(category)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}
