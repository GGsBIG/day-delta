import SwiftUI

struct ContentView: View {
    @State private var events: [Event] = EventStore.load()
    @State private var editing: Event?
    @State private var showingAdd = false

    private var sorted: [Event] {
        events.sorted { abs(dayDelta(to: $0.targetDate)) < abs(dayDelta(to: $1.targetDate)) }
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
        let t = deltaText(dayDelta(to: event.targetDate))
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
        .padding(.vertical, 6)
    }
}
