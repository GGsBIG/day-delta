import Foundation

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "America/New_York")!

func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}

// future -> positive
assert(dayDelta(to: day(2026, 1, 10), from: day(2026, 1, 1), calendar: cal) == 9)
// past -> negative
assert(dayDelta(to: day(2026, 1, 1), from: day(2026, 1, 31), calendar: cal) == -30)
// same calendar day, different hours -> 0 (the off-by-one guard)
assert(dayDelta(to: day(2026, 1, 1, 23), from: day(2026, 1, 1, 0), calendar: cal) == 0)
// across US DST spring-forward (2026-03-08) -> still a clean 2-day count
assert(dayDelta(to: day(2026, 3, 9), from: day(2026, 3, 7), calendar: cal) == 2)

// deltaText: future counts down, today/past counts up as a day-together number
assert(deltaText(5) == ("5", "days left"))      // future
assert(deltaText(0) == ("1", "days together"))  // started today -> day 1
assert(deltaText(-3) == ("4", "days together")) // 3 days ago -> day 4

// nextYearlyOccurrence: roll to next year only if this year's date already passed
func ymd(_ d: Date) -> (Int, Int, Int) {
    (cal.component(.year, from: d), cal.component(.month, from: d), cal.component(.day, from: d))
}
assert(ymd(nextYearlyOccurrence(of: day(2020, 3, 10), from: day(2026, 6, 15), calendar: cal)) == (2027, 3, 10))
assert(ymd(nextYearlyOccurrence(of: day(2020, 12, 25), from: day(2026, 6, 15), calendar: cal)) == (2026, 12, 25))

// nextMilestone: next multiple of 100 or 365, whichever comes first; nil for count-down
assert(nextMilestone(dayCount: 76)! == (100, 24))
assert(nextMilestone(dayCount: 100)! == (200, 100))
assert(nextMilestone(dayCount: 350)! == (365, 15))
assert(nextMilestone(dayCount: 0) == nil)
assert(nextMilestone(dayCount: -3) == nil)

// dateLabel: fixed format with weekday (2025-09-28 is a Sunday)
let enPOSIX = Locale(identifier: "en_US_POSIX")
assert(dateLabel(day(2025, 9, 28), calendar: cal, locale: enPOSIX) == "2025/09/28 (Sun)")

print("all DayMath tests passed")
