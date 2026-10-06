import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var events: [Event] = EventStore.load()
    @State private var viewing: Event?
    @State private var showingAdd = false
    @State private var sharingEvent: Event?
    @State private var exporting = false
    @State private var importing = false
    @AppStorage("autoSort") private var autoSort = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var editMode: EditMode = .inactive

    private var anniversaries: [Event] {
        events.filter { isAnniversaryToday($0.targetDate) }
    }

    /// Events in display order: manual (array) or auto (by proximity), with
    /// pinned events floated to the top in both cases.
    private var displayEvents: [Event] {
        let base = autoSort
            ? events.sorted { abs(dayDelta(to: $0.effectiveTarget())) < abs(dayDelta(to: $1.effectiveTarget())) }
            : events
        return base.filter(\.pinned) + base.filter { !$0.pinned }
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("DayDelta") {
                if !autoSort {
                    Button(editMode.isEditing ? "Done" : "Edit") {
                        withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                    }.foregroundStyle(Color.appInk)
                }
                Menu {
                    Toggle("Auto sort by date", isOn: $autoSort)
                    Button { exporting = true } label: { Label("Export…", systemImage: "square.and.arrow.up") }
                    Button { importing = true } label: { Label("Import…", systemImage: "square.and.arrow.down") }
                } label: { Image(systemName: "ellipsis.circle").foregroundStyle(Color.appInk) }
                Button { showingAdd = true } label: { Image(systemName: "plus").foregroundStyle(Color.appInk) }
            }
            Group {
                if events.isEmpty {
                    ContentUnavailableView("No events",
                        systemImage: "calendar",
                        description: Text("Tap + to add a date to count."))
                } else {
                    List {
                        if !anniversaries.isEmpty {
                            Section("On this day") {
                                ForEach(anniversaries) { event in
                                    row(event)
                                }
                            }
                        }
                        Section {
                            ForEach(displayEvents) { event in
                                row(event)
                                    .swipeActions(edge: .leading) {
                                        Button { togglePin(event) } label: {
                                            Label(event.pinned ? "Unpin" : "Pin",
                                                  systemImage: event.pinned ? "pin.slash" : "pin")
                                        }.tint(.gray)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button { sharingEvent = event } label: {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }.tint(.blue)
                                    }
                            }
                            .onMove { from, to in
                                guard !autoSort else { return }
                                events.move(fromOffsets: from, toOffset: to); persist()
                            }
                            .onDelete { offsets in
                                let ids = offsets.map { displayEvents[$0].id }
                                events.removeAll { ids.contains($0.id) }
                                persist()
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, $editMode)
                }
            }
        }
        .tint(.white)
        .onAppear { Notifications.requestAuthIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Notifications.sync(events) }
        }
        .fullScreenCover(item: $viewing) { event in
            NavigationStack {
                MemoryDetailView(event: event, onUpdate: updateEvent)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { viewing = nil }
                        }
                    }
            }
            .preferredColorScheme(.dark).tint(.white)
        }
        .sheet(item: $sharingEvent) { event in ShareSheet(event: event) }
        .fileExporter(isPresented: $exporting,
                      document: EventsDocument(data: exportData()),
                      contentType: .json,
                      defaultFilename: "daydelta-backup") { _ in }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.json]) { handleImport($0) }
        .sheet(isPresented: $showingAdd) {
            EventEditView(event: nil) { saved in
                events.append(saved); persist()
            }
        }
    }

    @ViewBuilder
    private func row(_ event: Event) -> some View {
        EventRow(event: event)
            .legible()
            .listRowBackground(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { viewing = event }
    }

    /// Upsert an edited event back into the list.
    private func updateEvent(_ saved: Event) {
        if let i = events.firstIndex(where: { $0.id == saved.id }) {
            events[i] = saved
        } else {
            events.append(saved)
        }
        persist()
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

    private func exportData() -> Data {
        let payload = BackupData(events: events,
                                 txns: TxnStore.load(),
                                 categories: CategoryStore.load(),
                                 accounts: AccountStore.load())
        return (try? JSONEncoder().encode(payload)) ?? Data()
    }

    /// Merge an imported backup. Accepts the new wrapper format and falls back to
    /// a legacy bare `[Event]` array. Upserts every record by id.
    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }

        if let backup = try? JSONDecoder().decode(BackupData.self, from: data) {
            merge(backup.events)
            mergeTxns(backup.txns)
            mergeCategories(backup.categories)
            mergeAccounts(backup.accounts)
        } else if let legacy = try? JSONDecoder().decode([Event].self, from: data) {
            merge(legacy)
        }
        persist()
    }

    private func merge(_ imported: [Event]) {
        for e in imported {
            if let i = events.firstIndex(where: { $0.id == e.id }) { events[i] = e }
            else { events.append(e) }
        }
    }

    private func mergeTxns(_ imported: [Txn]) {
        var txns = TxnStore.load()
        for t in imported {
            if let i = txns.firstIndex(where: { $0.id == t.id }) { txns[i] = t }
            else { txns.append(t) }
        }
        TxnStore.save(txns)
    }

    private func mergeCategories(_ imported: [Category]) {
        var cats = CategoryStore.load()
        for c in imported {
            if let i = cats.firstIndex(where: { $0.id == c.id }) { cats[i] = c }
            else { cats.append(c) }
        }
        CategoryStore.save(cats)
    }

    private func mergeAccounts(_ imported: [Account]) {
        var accs = AccountStore.load()
        for a in imported {
            if let i = accs.firstIndex(where: { $0.id == a.id }) { accs[i] = a }
            else { accs.append(a) }
        }
        AccountStore.save(accs)
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
                                .foregroundStyle(Color.appInk.opacity(0.6))
                        }
                        Text(event.title)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Color.appInk.opacity(0.6))
                        if event.pinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2).foregroundStyle(Color.appInk.opacity(0.6))
                        }
                    }
                    Text(event.label ?? t.subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.appInk.opacity(0.6))
                }
                Spacer()
                Text(t.number)
                    .font(.system(size: 44, design: .rounded))
                    .foregroundStyle(Color.appInk)
            }
            Text(dateLabel(target))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.appInk.opacity(0.6))
            if delta <= 0, event.mode == .dayCounter, let m = nextMilestone(dayCount: -delta + 1) {
                Text("next: \(m.target) · \(m.daysAway) days")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.appInk.opacity(0.6))
            }
        }
        .padding(.vertical, 6)
    }
}
