import SwiftUI

struct ContentView: View {
    @State private var events: [Event] = EventStore.load()
    @State private var editing: Event?
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView("No events",
                        systemImage: "calendar",
                        description: Text("Tap + to add a date to count."))
                } else {
                    List {
                        // Manual order is the source of truth; drag to reorder.
                        ForEach(events) { event in
                            EventRow(event: event)
                                .listRowBackground(Color.black)
                                .contentShape(Rectangle())
                                .onTapGesture { editing = event }
                                .swipeActions(edge: .leading) {
                                    Button { togglePin(event) } label: {
                                        Label(event.pinned ? "Unpin" : "Pin",
                                              systemImage: event.pinned ? "pin.slash" : "pin")
                                    }.tint(.gray)
                                }
                        }
                        .onMove { events.move(fromOffsets: $0, toOffset: $1); persist() }
                        .onDelete { events.remove(atOffsets: $0); persist() }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.black)
            .navigationTitle("DayDelta")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .tint(.white)
        .onAppear { Notifications.requestAuthIfNeeded() }
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

    /// Pin also floats the event to the top; unpin just clears the flag.
    private func togglePin(_ event: Event) {
        guard let i = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[i].pinned.toggle()
        if events[i].pinned {
            let e = events.remove(at: i)
            events.insert(e, at: 0)
        }
        persist()
    }

    private func persist() {
        EventStore.save(events)
        Notifications.sync(events)
    }
}

struct EventRow: View {
    let event: Event
    var body: some View {
        let target = event.effectiveTarget()
        let delta = dayDelta(to: target)
        let t = countDisplay(delta: delta, mode: event.mode)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if let icon = event.icon {
                            Image(icon).renderingMode(.template).resizable().scaledToFit()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(.gray)
                        }
                        Text(event.title)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.gray)
                        if event.pinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2).foregroundStyle(.gray)
                        }
                    }
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
            if delta <= 0, event.mode == .dayCounter, let m = nextMilestone(dayCount: -delta + 1) {
                Text("next: \(m.target) · \(m.daysAway) days")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
