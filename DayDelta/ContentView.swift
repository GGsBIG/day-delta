import SwiftUI

struct ContentView: View {
    @State private var events: [Event] = EventStore.load()
    @State private var editing: Event?
    @State private var showingAdd = false

    private var sorted: [Event] {
        events.sorted { abs(dayDelta(to: $0.effectiveTarget())) < abs(dayDelta(to: $1.effectiveTarget())) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView("No events",
                        systemImage: "calendar",
                        description: Text("Tap + to add a date to count."))
                } else {
                    List {
                        ForEach(sorted) { event in
                            EventRow(event: event)
                                .listRowBackground(Color.black)
                                .contentShape(Rectangle())
                                .onTapGesture { editing = event }
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.black)
            .navigationTitle("DayDelta")
            .toolbar {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .tint(.white)
        .sheet(isPresented: $showingAdd) {
            EventEditView(event: nil) { saved in
                events.append(saved); persist()
            }
        }
        .sheet(item: $editing) { event in
            EventEditView(event: event) { saved in
                if let i = events.firstIndex(where: { $0.id == saved.id }) {
                    events[i] = saved; persist()
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let ids = offsets.map { sorted[$0].id }
        events.removeAll { ids.contains($0.id) }
        persist()
    }

    private func persist() { EventStore.save(events) }
}

struct EventRow: View {
    let event: Event
    var body: some View {
        let target = event.effectiveTarget()
        let delta = dayDelta(to: target)
        let t = deltaText(delta)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.gray)
                    Text(t.subtitle)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.gray)
                }
                Spacer()
                Text(t.number)
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            Text(dateLabel(target))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            if delta <= 0, let m = nextMilestone(dayCount: -delta + 1) {
                Text("next: \(m.target) · \(m.daysAway) days")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
