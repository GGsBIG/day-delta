import SwiftUI

/// A shareable black/monospace countdown card for one event.
struct CountdownCard: View {
    let event: Event

    var body: some View {
        let target = event.effectiveTarget()
        let delta = dayDelta(to: target)
        let t = countDisplay(delta: delta, mode: event.mode)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let icon = event.icon {
                    Image(icon).renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 22, height: 22).foregroundStyle(.gray)
                }
                Text(event.title)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(t.number)
                .font(.system(size: 120, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.3)
                .lineLimit(1)
            Text(t.subtitle)
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(.gray)
            Text(dateLabel(target))
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text("△ DayDelta")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 340, height: 340, alignment: .leading)
        .background(Color.black)
    }
}

/// Renders `CountdownCard` to an image and offers a share sheet.
struct ShareSheet: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @State private var image: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                CountdownCard(event: event)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                if let image {
                    ShareLink(item: image, preview: SharePreview(event.title, image: image)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(.body, design: .monospaced))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .task { render() }
    }

    @MainActor private func render() {
        let renderer = ImageRenderer(content: CountdownCard(event: event))
        renderer.scale = 3
        if let ui = renderer.uiImage { image = Image(uiImage: ui) }
    }
}
