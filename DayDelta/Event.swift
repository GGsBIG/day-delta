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
    var note: String? = nil
    var photoFile: String? = nil
    /// Overrides the auto subtitle ("days left"/"days ago"/…). nil = auto.
    var label: String? = nil

    init(id: UUID = UUID(), title: String, targetDate: Date,
         mode: CountMode = .auto, recurrence: Recurrence = .none,
         icon: String? = nil, notify: Bool = false,
         notifyDaysBefore: Int = 0, pinned: Bool = false,
         note: String? = nil, photoFile: String? = nil, label: String? = nil) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.mode = mode
        self.recurrence = recurrence
        self.icon = icon
        self.notify = notify
        self.notifyDaysBefore = notifyDaysBefore
        self.pinned = pinned
        self.note = note
        self.photoFile = photoFile
        self.label = label
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, targetDate, mode, recurrence, icon, notify, notifyDaysBefore, pinned
        case note, photoFile, label
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
        try c.encodeIfPresent(note, forKey: .note)
        try c.encodeIfPresent(photoFile, forKey: .photoFile)
        try c.encodeIfPresent(label, forKey: .label)
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
        note = try c.decodeIfPresent(String.self, forKey: .note)
        photoFile = try c.decodeIfPresent(String.self, forKey: .photoFile)
        label = try c.decodeIfPresent(String.self, forKey: .label)
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
    private static var cache: [Event]?

    static func load() -> [Event] {
        if let cache { return cache }
        let events = (AppGroup.defaults.data(forKey: key))
            .flatMap { try? JSONDecoder().decode([Event].self, from: $0) } ?? []
        cache = events
        return events
    }

    static func save(_ events: [Event]) {
        cache = events
        guard let data = try? JSONEncoder().encode(events) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }
}
