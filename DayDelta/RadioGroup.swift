import SwiftUI

/// One radio row: an animated indicator (ring + inner dot that springs in when
/// selected) plus trailing label content. Tapping selects.
struct RadioRow<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.35),
                                      lineWidth: 2)
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .scaleEffect(isSelected ? 1 : 0.01)
                        .opacity(isSelected ? 1 : 0)
                }
                label()
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.bouncy(duration: 0.35), value: isSelected)
    }
}

/// Category chooser as a vertical animated radio group.
struct CategoryRadioGroup: View {
    let categories: [Category]
    @Binding var selection: UUID?

    var body: some View {
        VStack(spacing: 4) {
            ForEach(categories) { c in
                RadioRow(isSelected: selection == c.id) {
                    selection = c.id
                } label: {
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: c.colorHex)).frame(width: 12, height: 12)
                        Text(c.name).font(.system(.body, design: .monospaced))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
