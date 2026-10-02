import SwiftUI

/// A category picker: a tappable field that opens a popover whose rows reveal
/// top-to-bottom with a staggered spring. ponytail: dismisses on select or by
/// tapping the field again; no outside-tap scrim (add if it feels needed).
struct CategoryDropdown: View {
    let categories: [Category]
    @Binding var selection: UUID?

    @State private var open = false
    @State private var appeared = false

    private var selected: Category? { categories.first { $0.id == selection } }

    var body: some View {
        Button {
            withAnimation(.bouncy(duration: 0.3)) { open.toggle() }
        } label: {
            HStack(spacing: 8) {
                if let s = selected {
                    Circle().fill(Color(hex: s.colorHex)).frame(width: 12, height: 12)
                    Text(s.name)
                } else {
                    Text("Select category").foregroundStyle(.gray)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(open ? 180 : 0))
                    .foregroundStyle(.gray)
            }
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if open { popover.offset(y: 48) }
        }
        .zIndex(open ? 1 : 0)
    }

    private var popover: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(categories.enumerated()), id: \.element.id) { i, c in
                row(c, index: i)
            }
        }
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.14)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
        .transition(.opacity)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }

    private func row(_ c: Category, index: Int) -> some View {
        Button {
            selection = c.id
            withAnimation(.bouncy(duration: 0.3)) { open = false }
        } label: {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: c.colorHex)).frame(width: 12, height: 12)
                Text(c.name).font(.system(.body, design: .monospaced))
                Spacer()
                if c.id == selection {
                    Image(systemName: "checkmark").font(.caption.bold())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .frame(width: 240, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -8)
        .animation(.spring(response: 0.3, dampingFraction: 0.7)
                    .delay(Double(index) * 0.04), value: appeared)
    }
}
