import Foundation

/// Asset names in Shared/EventIcons.xcassets, in picker order. `nil` = no icon.
let eventIconNames = [
    "ic-heart", "ic-star", "ic-cake", "ic-gift", "ic-plane", "ic-flag",
    "ic-book", "ic-briefcase", "ic-ring", "ic-target", "ic-clock", "ic-graduation",
]

/// SF Symbols offered for categories (rendered with Image(systemName:)). ~200
/// well-known symbols grouped by theme to pick from for a custom category.
let categoryIconNames = [
    // Food & drink
    "fork.knife", "cup.and.saucer.fill", "mug.fill", "wineglass.fill",
    "takeoutbag.and.cup.and.straw.fill", "birthday.cake.fill", "carrot.fill",
    "fish.fill", "popcorn.fill", "waterbottle.fill", "frying.pan.fill", "cupcake",
    // Shopping
    "cart.fill", "bag.fill", "basket.fill", "handbag.fill", "giftcard.fill",
    "tag.fill", "barcode", "shippingbox.fill", "creditcard.fill", "wallet.pass.fill",
    // Money & finance
    "dollarsign.circle.fill", "centsign.circle.fill", "eurosign.circle.fill",
    "yensign.circle.fill", "sterlingsign.circle.fill", "bitcoinsign.circle.fill",
    "banknote.fill", "building.columns.fill", "chart.line.uptrend.xyaxis",
    "chart.pie.fill", "chart.bar.fill", "percent", "coloncurrencysign.circle.fill",
    "arrow.up.arrow.down.circle.fill", "giftcard", "piggybank.fill",
    // Transport
    "car.fill", "car.2.fill", "bus.fill", "tram.fill", "bicycle", "scooter",
    "fuelpump.fill", "airplane", "ferry.fill", "sailboat.fill", "fuelpump.circle.fill",
    "parkingsign.circle.fill", "road.lanes", "truck.box.fill", "motorcycle",
    "figure.walk", "tram.circle.fill", "cablecar.fill",
    // Home & utilities
    "house.fill", "house.circle.fill", "bed.double.fill", "sofa.fill", "lamp.table.fill",
    "lightbulb.fill", "bolt.fill", "drop.fill", "flame.fill", "humidity.fill",
    "washer.fill", "refrigerator.fill", "shower.fill", "toilet.fill", "sink.fill",
    "wifi", "spigot.fill", "key.fill", "wrench.and.screwdriver.fill", "hammer.fill",
    "paintbrush.fill", "paintroller.fill", "trash.fill", "leaf.fill",
    // Health & fitness
    "cross.case.fill", "pills.fill", "heart.fill", "bandage.fill", "stethoscope",
    "cross.fill", "dumbbell.fill", "figure.run", "figure.strengthtraining.traditional",
    "figure.yoga", "figure.pool.swim", "figure.cooldown", "bolt.heart.fill",
    "lungs.fill", "brain.head.profile", "tooth.fill", "eye.fill", "eyeglasses",
    "waveform.path.ecg", "syringe.fill", "testtube.2",
    // Beauty & apparel
    "tshirt.fill", "shoe.fill", "comb.fill", "scissors", "handbag", "hanger",
    "sunglasses.fill", "crown.fill", "sparkles",
    // Tech & devices
    "iphone", "ipad", "macbook", "applewatch", "headphones", "airpods",
    "desktopcomputer", "tv.fill", "gamecontroller.fill", "keyboard.fill",
    "printer.fill", "camera.fill", "video.fill", "phone.fill", "simcard.fill",
    "externaldrive.fill", "server.rack", "antenna.radiowaves.left.and.right",
    "wifi.router.fill", "battery.100", "powerplug.fill", "cpu.fill",
    // Entertainment & media
    "music.note", "music.mic", "film.fill", "popcorn", "theatermasks.fill",
    "ticket.fill", "guitars.fill", "pianokeys", "paintpalette.fill", "photo.fill",
    "play.rectangle.fill", "dice.fill", "puzzlepiece.fill", "books.vertical.fill",
    "book.fill", "newspaper.fill", "radio.fill", "headphones.circle.fill",
    // Travel & places
    "map.fill", "mappin.and.ellipse", "globe.americas.fill", "beach.umbrella.fill",
    "tent.fill", "mountain.2.fill", "building.2.fill", "suitcase.fill",
    "backpack.fill", "binoculars.fill", "camera.viewfinder", "signpost.right.fill",
    "location.fill", "airplane.departure",
    // Nature & weather
    "sun.max.fill", "cloud.fill", "cloud.rain.fill", "snowflake", "wind",
    "moon.stars.fill", "tree.fill", "pawprint.fill", "tortoise.fill", "bird.fill",
    "ant.fill", "ladybug.fill", "fossil.shell.fill", "camera.macro", "sparkle",
    // People & activities
    "person.fill", "person.2.fill", "person.3.fill", "figure.and.child.holdinghands",
    "hands.clap.fill", "hand.thumbsup.fill", "gift.fill", "balloon.fill",
    "party.popper.fill", "fireworks", "trophy.fill", "medal.fill", "flag.fill",
    "bell.fill", "megaphone.fill", "bubble.left.and.bubble.right.fill",
    // Work & education
    "briefcase.fill", "case.fill", "graduationcap.fill", "studentdesk",
    "pencil.and.ruler.fill", "ruler.fill", "paperclip", "folder.fill",
    "doc.fill", "calendar", "clock.fill", "envelope.fill", "building.fill",
    "lightbulb.max.fill", "function", "text.book.closed.fill",
    // Misc & symbols
    "gearshape.fill", "gift.circle.fill", "shield.fill", "lock.fill", "bell.badge.fill",
    "star.fill", "bookmark.fill", "pin.fill", "flame.circle.fill", "cube.fill",
    "shippingbox.circle.fill", "ellipsis.circle.fill",
]

/// Whole-day difference between two dates, each normalized to start-of-day.
/// Positive = target in the future (countdown), negative = past (count-up), 0 = today.
/// Normalizing both to startOfDay first avoids the off-by-one where a sub-24h
/// gap would otherwise round to 0.
func dayDelta(to target: Date, from now: Date = Date(), calendar: Calendar = .current) -> Int {
    let a = calendar.startOfDay(for: now)
    let b = calendar.startOfDay(for: target)
    return calendar.dateComponents([.day], from: a, to: b).day ?? 0
}

/// How a single event turns its day-delta into text.
/// `auto` = future counts down, past counts up ("N days ago"), 0 = today.
/// `dayCounter` = inclusive "Day N" counter (start day is day 1) for today/past.
enum CountMode: String, Codable, CaseIterable, Sendable {
    case auto
    case dayCounter
}

/// Big number + subtitle for a delta under a given mode.
func countDisplay(delta: Int, mode: CountMode) -> (number: String, subtitle: String) {
    switch mode {
    case .dayCounter:
        if delta > 0 { return ("\(delta)", "days left") } // counter start still ahead
        return ("\(-delta + 1)", "days")                  // Day N, start day = 1
    case .auto:
        if delta > 0 { return ("\(delta)", "days left") }
        if delta < 0 { return ("\(-delta)", "days ago") }
        return ("0", "today")
    }
}

/// How an event's date repeats.
enum Recurrence: String, Codable, CaseIterable, Sendable {
    case none
    case weekly
    case monthly
    case yearly

    var component: Calendar.Component? {
        switch self {
        case .none:    return nil
        case .weekly:  return .weekOfYear
        case .monthly: return .month
        case .yearly:  return .year
        }
    }
}

/// The next occurrence of `date` on/after today under a recurrence rule.
/// `.none` returns the date unchanged; otherwise the anchor is stepped forward
/// by the recurrence unit until it reaches today or later.
/// ponytail: naive forward stepping capped at 1000 iterations — plenty for any
/// personal date range; direct arithmetic isn't worth the edge-case risk.
func nextOccurrence(of date: Date, recurrence: Recurrence,
                    from now: Date = Date(), calendar: Calendar = .current) -> Date {
    guard let unit = recurrence.component else { return date }
    let today = calendar.startOfDay(for: now)
    var d = calendar.startOfDay(for: date)
    var steps = 0
    while d < today, steps < 1000 {
        guard let next = calendar.date(byAdding: unit, value: 1, to: d) else { break }
        d = calendar.startOfDay(for: next)
        steps += 1
    }
    return d
}

/// The next milestone strictly greater than `dayCount`, drawn from multiples of
/// 100 and 365 (whichever comes first), plus how many days away it is.
/// Returns nil for a count-down (dayCount <= 0), where milestones don't apply.
func nextMilestone(dayCount: Int) -> (target: Int, daysAway: Int)? {
    guard dayCount > 0 else { return nil }
    let hundred = (dayCount / 100 + 1) * 100
    let year = (dayCount / 365 + 1) * 365
    let target = min(hundred, year)
    return (target, target - dayCount)
}

/// True when `date` shares today's month and day (an anniversary of it).
func isAnniversaryToday(_ date: Date, today: Date = Date(), calendar: Calendar = .current) -> Bool {
    let a = calendar.dateComponents([.month, .day], from: date)
    let b = calendar.dateComponents([.month, .day], from: today)
    return a.month == b.month && a.day == b.day
}

/// When a reminder should fire: `daysBefore` days before `target`, at `hour`:00.
func notifyDate(target: Date, daysBefore: Int, hour: Int = 9,
                calendar: Calendar = .current) -> Date {
    let day = calendar.date(byAdding: .day, value: -daysBefore,
                            to: calendar.startOfDay(for: target)) ?? target
    return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
}

/// A fixed, sortable date label with weekday, e.g. "2025/09/28 (Sun)".
func dateLabel(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
    let f = DateFormatter()
    f.calendar = calendar
    f.timeZone = calendar.timeZone
    f.locale = locale
    f.dateFormat = "yyyy/MM/dd (EEE)"
    return f.string(from: date)
}
