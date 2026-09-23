import AppIntents

// AppEnum conformances live in the widget target (AppIntents is widget-side).
// The underlying enums are defined in Shared/DayMath.swift.

extension CountMode: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Count Mode" }
    static var caseDisplayRepresentations: [CountMode: DisplayRepresentation] {
        [.auto: "Auto (until / since)", .dayCounter: "Day counter"]
    }
}

extension Recurrence: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Repeat" }
    static var caseDisplayRepresentations: [Recurrence: DisplayRepresentation] {
        [.none: "Never", .weekly: "Weekly", .monthly: "Monthly", .yearly: "Yearly"]
    }
}

/// The widget's icon parameter. Maps to an asset name in EventIcons.xcassets.
enum IconChoice: String, AppEnum, CaseIterable {
    case none, heart, star, cake, gift, plane, flag, book, briefcase, ring, target, clock, graduation

    var assetName: String? { self == .none ? nil : "ic-\(rawValue)" }

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Icon" }
    static var caseDisplayRepresentations: [IconChoice: DisplayRepresentation] {
        [.none: "None", .heart: "Heart", .star: "Star", .cake: "Cake", .gift: "Gift",
         .plane: "Plane", .flag: "Flag", .book: "Book", .briefcase: "Briefcase",
         .ring: "Ring", .target: "Target", .clock: "Clock", .graduation: "Graduation"]
    }
}
