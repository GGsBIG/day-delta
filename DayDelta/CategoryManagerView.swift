import SwiftUI
import UIKit

/// A category's badge: its color disc with its SF Symbol icon (if any). Shared by
/// the ledger, stats, and category manager.
struct CategoryBadge: View {
    let category: Category
    var size: CGFloat = 28
    var body: some View {
        Circle().fill(Color(hex: category.colorHex))
            .frame(width: size, height: size)
            .overlay {
                if let icon = category.icon, UIImage(systemName: icon) != nil {
                    Image(systemName: icon).font(.system(size: size * 0.5))
                        .foregroundStyle(.white)
                }
            }
    }
}

/// Grid of SF Symbols for choosing a category icon. Tapping the current one clears it.
struct CategoryIconPicker: View {
    @Binding var selection: String?
    private let cols = [GridItem(.adaptive(minimum: 46), spacing: 10)]
    var body: some View {
        LazyVGrid(columns: cols, spacing: 10) {
            ForEach(categoryIconNames, id: \.self) { name in
                let on = selection == name
                Image(systemName: name)
                    .font(.system(size: 18))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(on ? .white : Color.appInk)
                    .background(RoundedRectangle(cornerRadius: UI.radius)
                        .fill(on ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.appInk.opacity(0.08))))
                    .contentShape(RoundedRectangle(cornerRadius: UI.radius))
                    .onTapGesture { selection = on ? nil : name }
            }
        }
    }
}

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
            CategoryBadge(category: c, size: 28)
            Text(c.name.isEmpty ? "(unnamed)" : c.name)
            Spacer()
            if c.builtin { Text("built-in").foregroundStyle(Color.appInk.opacity(0.6)).font(.caption) }
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
                Section("Icon") { CategoryIconPicker(selection: $category.icon) }
                if category.type == .expense {
                    Section {
                        Toggle("Count as investment / savings", isOn: $category.isInvestment)
                    } footer: {
                        Text("Money here (e.g. buying stocks) counts as saved, not spent, in \"You've saved this month\".")
                    }
                }
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
