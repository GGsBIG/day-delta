import Foundation

struct Event: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var targetDate: Date
    var repeatsYearly: Bool = false

    init(id: UUID = UUID(), title: String, targetDate: Date, repeatsYearly: Bool = false) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.repeatsYearly = repeatsYearly
    }

    // Custom decode so events saved before `repeatsYearly` existed still load
    // (synthesized Codable would throw on the missing key).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        targetDate = try c.decode(Date.self, forKey: .targetDate)
        repeatsYearly = try c.decodeIfPresent(Bool.self, forKey: .repeatsYearly) ?? false
    }
}

extension Event {
    /// The date to actually count to: next yearly occurrence for repeating
    /// events, otherwise the stored date.
    func effectiveTarget(now: Date = .now, calendar: Calendar = .current) -> Date {
        repeatsYearly ? nextYearlyOccurrence(of: targetDate, from: now, calendar: calendar) : targetDate
    }
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
