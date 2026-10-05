import SwiftUI

/// Pushed category chooser. Tapping a row sets the selection and pops back.
struct CategoryPickerView: View {
    let categories: [Category]
    @Binding var selection: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(categories) { c in
                Button {
                    selection = c.id
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: c.colorHex)).frame(width: 12, height: 12)
                        Text(c.name)
                        Spacer()
                        if selection == c.id { Image(systemName: "checkmark").foregroundStyle(Color.appInk) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(GrainientBackground())
        .font(.system(.body, design: .rounded))
        .foregroundStyle(Color.appInk)
        .navigationTitle("Category")
    }
}
