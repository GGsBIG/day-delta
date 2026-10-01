import SwiftUI

/// Read view for one event: photo backdrop (if any) with the big monospaced
/// number, title, date and note on top.
struct MemoryDetailView: View {
    @State var event: Event
    let onUpdate: (Event) -> Void

    @State private var editing = false
    @State private var sharing = false

    var body: some View {
        let target = event.effectiveTarget()
        let t = countDisplay(delta: dayDelta(to: target), mode: event.mode)

        ZStack {
            Color.black.ignoresSafeArea()
            if let photoFile = event.photoFile, let ui = PhotoStore.load(photoFile) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
                    .ignoresSafeArea()
                LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.85)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                HStack(spacing: 8) {
                    if let icon = event.icon {
                        Image(icon).renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 20, height: 20).foregroundStyle(.gray)
                    }
                    Text(event.title)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(.gray)
                }
                Text(t.number)
                    .font(.system(size: 96, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.3).lineLimit(1)
                Text(event.label ?? t.subtitle)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundStyle(.gray)
                Text(dateLabel(target))
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let note = event.note {
                    Text(note)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 8)
                }
                let spent = TxnStore.load()
                    .filter { $0.eventID == event.id && $0.type == .expense }
                    .reduce(Decimal(0)) { $0 + $1.amount }
                if spent > 0 {
                    Text("這趟花費 " + formatMoney(spent))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sharing = true } label: { Image(systemName: "square.and.arrow.up") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .sheet(isPresented: $editing) {
            EventEditView(event: event) { saved in
                event = saved
                onUpdate(saved)
            }
        }
        .sheet(isPresented: $sharing) { ShareSheet(event: event) }
    }
}
