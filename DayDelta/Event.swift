import Foundation

struct Event: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var targetDate: Date
    var mode: CountMode = .auto
    var recurrence: Recurrence = .none
    var icon: String? = nil
    var notify: Bool = false
    var notifyDaysBefore: Int = 0
    var pinned: Bool = false

    init(id: UUID = UUID(), title: String, targetDate: Date,
         mode: CountMode = .auto, recurrence: Recurrence = .none,
         icon: String? = nil, notify: Bool = false,
         notifyDaysBefore: Int = 0, pinned: Bool = false) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.mode = mode
        self.recurrence = recurrence
        self.icon = icon
        self.notify = notify
        self.notifyDaysBefore = notifyDaysBefore
        self.pinned = pinned
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, targetDate, mode, recurrence, icon, notify, notifyDaysBefore, pinned
        case repeatsYearly // legacy, decode-only
    }

    // Explicit encode: the extra legacy `repeatsYearly` CodingKey blocks
    // synthesized Encodable, and new saves should use the current schema only.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(targetDate, forKey: .targetDate)
        try c.encode(mode, forKey: .mode)
        try c.encode(recurrence, forKey: .recurrence)
        try c.encodeIfPresent(icon, forKey: .icon)
        try c.encode(notify, forKey: .notify)
        try c.encode(notifyDaysBefore, forKey: .notifyDaysBefore)
        try c.encode(pinned, forKey: .pinned)
    }

    // Custom decode so events saved by earlier versions still load: every new
    // field is optional-with-default, and the legacy `repeatsYearly` Bool maps
    // to `.yearly`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        targetDate = try c.decode(Date.self, forKey: .targetDate)
        mode = try c.decodeIfPresent(CountMode.self, forKey: .mode) ?? .auto
        icon = try c.decodeIfPresent(String.self, forKey: .icon)
        notify = try c.decodeIfPresent(Bool.self, forKey: .notify) ?? false
        notifyDaysBefore = try c.decodeIfPresent(Int.self, forKey: .notifyDaysBefore) ?? 0
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        if let r = try c.decodeIfPresent(Recurrence.self, forKey: .recurrence) {
            recurrence = r
        } else if try c.decodeIfPresent(Bool.self, forKey: .repeatsYearly) == true {
            recurrence = .yearly
        } else {
            recurrence = .none
        }
    }
}

extension Event {
    /// The date to actually count to: next occurrence for recurring events,
    /// otherwise the stored date.
    func effectiveTarget(now: Date = .now, calendar: Calendar = .current) -> Date {
        nextOccurrence(of: targetDate, recurrence: recurrence, from: now, calendar: calendar)
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
