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

// deltaText: magnitude + tense
assert(deltaText(5) == ("5", "days left"))
assert(deltaText(-3) == ("3", "days ago"))
assert(deltaText(0) == ("0", "today"))

print("all DayMath tests passed")
