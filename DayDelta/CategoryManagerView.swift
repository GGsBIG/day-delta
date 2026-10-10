import SwiftUI
import UIKit

/// A category's mark, in its color: the SF Symbol glyph if set (no background),
/// else a small dot. Shared by the ledger, stats, and category manager.
struct CategoryBadge: View {
    let category: Category
    var size: CGFloat = 28
    var body: some View {
        let color = Color(hex: category.colorHex)
        Group {
            if let icon = category.icon, UIImage(systemName: icon) != nil {
                Image(systemName: icon).font(.system(size: size * 0.8))
                    .foregroundStyle(color)
            } else {
                Circle().fill(color).frame(width: size * 0.45, height: size * 0.45)
            }
        }
        .frame(width: size, height: size)
    }
}

/// SF Symbols the running OS actually has — filtered once (the ~200 `UIImage`
/// lookups are expensive, so never redo them on every render).
private let availableCategoryIcons = categoryIconNames.filter { UIImage(systemName: $0) != nil }

/// Grid of SF Symbols for choosing a category icon. Tapping the current one clears it.
struct CategoryIconPicker: View {
    @Binding var selection: String?
    private let cols = [GridItem(.adaptive(minimum: 46), spacing: 10)]
    var body: some View {
        // ~200 icons would make the form section huge; scroll within a fixed box.
        ScrollView {
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(availableCategoryIcons, id: \.self) { name in
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
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)   // the bar used to sit on top of the last column
        .frame(height: 260)
    }
}

/// Add / rename / recolor / delete categories. Built-ins can't be deleted.
struct CategoryManagerView: View {
    @Binding var categories: [Category]

    @State private var editing: Category?
    @State private var adding = false
    @State private var confirmingReset = false

    private let colors = categoryColors

    var body: some View {
        List {
            ForEach(TxnType.allCases, id: \.self) { type in
                Section(type == .expense ? "Expense" : "Income") {
                    ForEach(categories.filter { $0.type == type && !$0.isTransfer }) { c in
                        Button { editing = c } label: { row(c) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in delete(type: type, offsets: offsets) }
                    .onMove { from, to in move(type: type, from: from, to: to) }
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
        .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
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
            CategoryBadge(category: c, size: 22)
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

    /// The visible rows for a type, in display order (same predicate as the ForEach,
    /// so swipe/drag offsets line up exactly).
    private func visible(_ type: TxnType) -> [Category] {
        categories.filter { $0.type == type && !$0.isTransfer }
    }

    /// Delete exactly the swiped rows. (Offsets must match the ForEach's rows or the
    /// List data/animation desync and the app crashes.)
    private func delete(type: TxnType, offsets: IndexSet) {
        let ids = offsets.map { visible(type)[$0].id }
        categories.removeAll { ids.contains($0.id) }
    }

    /// Reorder within a type's section: reshuffle that slice and write it back into
    /// `categories` in place, leaving the other type's rows untouched.
    private func move(type: TxnType, from: IndexSet, to: Int) {
        var slice = visible(type)
        slice.move(fromOffsets: from, toOffset: to)
        var next = slice.makeIterator()
        categories = categories.map { ($0.type == type && !$0.isTransfer) ? next.next()! : $0 }
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
