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

// countDisplay .auto: future counts down, past counts up ("days ago"), 0 = today
assert(countDisplay(delta: 5, mode: .auto) == ("5", "days left"))
assert(countDisplay(delta: 0, mode: .auto) == ("0", "today"))
assert(countDisplay(delta: -3, mode: .auto) == ("3", "days ago"))
// countDisplay .dayCounter: inclusive Day N for today/past, countdown for future
assert(countDisplay(delta: 0, mode: .dayCounter) == ("1", "days"))   // started today -> day 1
assert(countDisplay(delta: -3, mode: .dayCounter) == ("4", "days"))  // 3 days ago -> day 4
assert(countDisplay(delta: 5, mode: .dayCounter) == ("5", "days left"))

// nextOccurrence: roll forward to today-or-later by the recurrence unit
func ymd(_ d: Date) -> (Int, Int, Int) {
    (cal.component(.year, from: d), cal.component(.month, from: d), cal.component(.day, from: d))
}
assert(ymd(nextOccurrence(of: day(2020, 3, 10), recurrence: .yearly, from: day(2026, 6, 15), calendar: cal)) == (2027, 3, 10))
assert(ymd(nextOccurrence(of: day(2020, 12, 25), recurrence: .yearly, from: day(2026, 6, 15), calendar: cal)) == (2026, 12, 25))
// .none leaves the date untouched
assert(ymd(nextOccurrence(of: day(2020, 1, 1), recurrence: .none, from: day(2026, 6, 15), calendar: cal)) == (2020, 1, 1))
// monthly: same day-of-month, first occurrence on/after today
assert(ymd(nextOccurrence(of: day(2026, 1, 20), recurrence: .monthly, from: day(2026, 6, 15), calendar: cal)) == (2026, 6, 20))
// weekly: 2026-06-01 is a Monday; next Monday on/after 2026-06-15 is 2026-06-15
assert(ymd(nextOccurrence(of: day(2026, 6, 1), recurrence: .weekly, from: day(2026, 6, 15), calendar: cal)) == (2026, 6, 15))

// nextMilestone: next multiple of 100 or 365, whichever comes first; nil for count-down
assert(nextMilestone(dayCount: 76)! == (100, 24))
assert(nextMilestone(dayCount: 100)! == (200, 100))
assert(nextMilestone(dayCount: 350)! == (365, 15))
assert(nextMilestone(dayCount: 0) == nil)
assert(nextMilestone(dayCount: -3) == nil)

// dateLabel: fixed format with weekday (2025-09-28 is a Sunday)
let enPOSIX = Locale(identifier: "en_US_POSIX")
assert(dateLabel(day(2025, 9, 28), calendar: cal, locale: enPOSIX) == "2025/09/28 (Sun)")

// isAnniversaryToday: month+day match regardless of year
assert(isAnniversaryToday(day(2020, 6, 15), today: day(2026, 6, 15), calendar: cal) == true)
assert(isAnniversaryToday(day(2020, 6, 14), today: day(2026, 6, 15), calendar: cal) == false)

// notifyDate: N days before target at 09:00
let fire = notifyDate(target: day(2026, 6, 15), daysBefore: 3, calendar: cal)
assert(ymd(fire) == (2026, 6, 12))
assert(cal.component(.hour, from: fire) == 9 && cal.component(.minute, from: fire) == 0)

// ---- Money logic ----

func cat(_ hex: String = "#000000") -> Category {
    Category(name: "c", type: .expense, icon: nil, colorHex: hex)
}
let foodID = UUID(), rideID = UUID(), payID = UUID()
func tx(_ amt: Decimal, _ cid: UUID, _ d: Date, _ type: TxnType = .expense) -> Txn {
    Txn(type: type, amount: amt, categoryID: cid, date: d)
}

let sample = [
    tx(100, foodID, day(2026, 6, 10)),
    tx(50,  foodID, day(2026, 6, 20)),
    tx(30,  rideID, day(2026, 6, 15)),
    tx(999, foodID, day(2026, 5, 10)),       // different month, excluded
    tx(5000, payID, day(2026, 6, 25), .income),
]

// txnsInPeriod: month of June 2026 keeps the four June rows, drops May
let june = txnsInPeriod(sample, period: .month, containing: day(2026, 6, 1), calendar: cal)
assert(june.count == 4)

// categoryTotals: expense only, descending by total
let totals = categoryTotals(june, type: .expense)
assert(totals.count == 2)
assert(totals[0].categoryID == foodID && totals[0].total == 150)
assert(totals[1].categoryID == rideID && totals[1].total == 30)

// income is separate
let inc = categoryTotals(june, type: .income)
assert(inc.count == 1 && inc[0].total == 5000)

// ---- Calendar logic ----

// daysInMonth: October 2026 has 31 days, first Oct 1, last Oct 31
let octDays = daysInMonth(containing: day(2026, 10, 15), calendar: cal)
assert(octDays.count == 31)
assert(ymd(octDays.first!) == (2026, 10, 1))
assert(ymd(octDays.last!) == (2026, 10, 31))

// leadingBlanks: Oct 1 2026 is a Thursday (weekday 5, Sun=1). Sunday-first -> 4 blanks.
var sunFirst = cal
sunFirst.firstWeekday = 1
assert(leadingBlanks(forMonthContaining: day(2026, 10, 10), calendar: sunFirst) == 4)
// Monday-first -> 3 blanks (Mon,Tue,Wed before Thursday).
var monFirst = cal
monFirst.firstWeekday = 2
assert(leadingBlanks(forMonthContaining: day(2026, 10, 10), calendar: monFirst) == 3)

// txnsOn: only the txns on that calendar day
let calTxns = [
    tx(100, foodID, day(2026, 10, 2)),
    tx(50,  rideID, day(2026, 10, 2)),
    tx(999, foodID, day(2026, 10, 3)),
]
assert(txnsOn(calTxns, day: day(2026, 10, 2), calendar: cal).count == 2)
assert(txnsOn(calTxns, day: day(2026, 10, 5), calendar: cal).isEmpty)

// dominantCategoryID: category of the single largest-amount txn
assert(dominantCategoryID(calTxns) == foodID)   // 999 is the max
assert(dominantCategoryID([]) == nil)

// addMonths: forward across year end and backward across year start
assert(ymd(addMonths(1, to: day(2026, 10, 15), calendar: cal)) == (2026, 11, 15))
assert(ymd(addMonths(-1, to: day(2026, 1, 10), calendar: cal)) == (2025, 12, 10))

// migrateCategoryNames: legacy Chinese builtin names -> English; ids kept; English untouched
let legacyFoodID = UUID()
let legacyCats = [
    Category(id: legacyFoodID, name: "餐飲", type: .expense, icon: nil, colorHex: "#4F9DFF", builtin: true),
    Category(name: "薪資", type: .income, icon: nil, colorHex: "#22C55E", builtin: true),
    Category(name: "Food", type: .expense, icon: nil, colorHex: "#4F9DFF", builtin: true),
]
let migratedCats = migrateCategoryNames(legacyCats)
assert(migratedCats[0].name == "Food" && migratedCats[0].id == legacyFoodID)
assert(migratedCats[1].name == "Salary")
assert(migratedCats[2].name == "Food")   // already English -> unchanged

// applyAmountKey: build digits, single dot, max 2 decimals, delete
assert(applyAmountKey("", .digit(1)) == "1")
assert(applyAmountKey("1", .digit(2)) == "12")
assert(applyAmountKey("0", .digit(5)) == "5")        // leading zero replaced
assert(applyAmountKey("", .dot) == "0.")             // dot on empty -> 0.
assert(applyAmountKey("0.", .dot) == "0.")           // no second dot
assert(applyAmountKey("1.23", .digit(4)) == "1.23")  // max 2 decimals
assert(applyAmountKey("1.2", .digit(5)) == "1.25")
assert(applyAmountKey("12", .delete) == "1")
assert(applyAmountKey("1", .delete) == "")
assert(applyAmountKey("", .delete) == "")

print("all DayMath tests passed")

print("all money tests passed")
