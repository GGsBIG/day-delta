import Foundation

struct Event: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var targetDate: Date
}

enum EventStore {
    private static let key = "daydelta.events"

    static func load() -> [Event] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let events = try? JSONDecoder().decode([Event].self, from: data)
        else { return [] }
        return events
    }

    static func save(_ events: [Event]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
