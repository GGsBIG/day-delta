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

// accountBalance: income - expense per account; nil = unassigned bucket
let accA = UUID(), accB = UUID()
let balTxns = [
    Txn(type: .income,  amount: 1000, categoryID: foodID, date: day(2026, 10, 1), accountID: accA),
    Txn(type: .expense, amount: 300,  categoryID: foodID, date: day(2026, 10, 2), accountID: accA),
    Txn(type: .expense, amount: 50,   categoryID: rideID, date: day(2026, 10, 2), accountID: accB),
    Txn(type: .expense, amount: 20,   categoryID: rideID, date: day(2026, 10, 3)),  // unassigned
]
assert(accountBalance(balTxns, accountID: accA) == 700)
assert(accountBalance(balTxns, accountID: accB) == -50)
assert(accountBalance(balTxns, accountID: nil) == -20)

// Transfer: 1000 from accA (expense) to accB (income) via a shared transferID.
// accA drops 1000, accB rises 1000, grand total unchanged.
let xferID = UUID(), xferCat = UUID()
let withTransfer = balTxns + [
    Txn(type: .expense, amount: 1000, categoryID: xferCat, date: day(2026, 10, 4), accountID: accA, transferID: xferID),
    Txn(type: .income,  amount: 1000, categoryID: xferCat, date: day(2026, 10, 4), accountID: accB, transferID: xferID),
]
assert(accountBalance(withTransfer, accountID: accA) == -300)   // 700 - 1000
assert(accountBalance(withTransfer, accountID: accB) == 950)    // -50 + 1000
let totalBefore = balTxns.reduce(Decimal(0)) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
let totalAfter = withTransfer.reduce(Decimal(0)) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
assert(totalBefore == totalAfter)   // transfer nets to zero
assert(withTransfer.filter { $0.transferID == xferID }.count == 2)   // two linked legs

// balanceSeries: 7 daily cumulative points ending today; accA climbs 1000 -> 700
let series = balanceSeries(balTxns, scope: accA, period: .week, now: day(2026, 10, 5), calendar: cal)
assert(series.count == 7)
assert(series.first(where: { ymd($0.date) == (2026, 10, 1) })?.balance == 1000)
assert(series.last?.balance == 700)
// grand total (scope nil) on 10/3 includes the unassigned -20: 1000-300-50-20 = 630
let allSeries = balanceSeries(balTxns, scope: nil, period: .week, now: day(2026, 10, 5), calendar: cal)
assert(allSeries.last?.balance == 630)

// Holding: cost, market value, unrealized gain
let h = Holding(kind: "US Stocks", name: "AAPL", quantity: 10, costPerUnit: 100, currentPrice: 120)
assert(h.cost == 1000)
assert(h.marketValue == 1200)
assert(h.gain == 200)
let loss = Holding(kind: "Gold", name: "XAU", quantity: 2, costPerUnit: 300, currentPrice: 250)
assert(loss.gain == -100)

// parseQuotePrice: pull regularMarketPrice out of Yahoo v8 chart JSON
let quoteJSON = #"{"chart":{"result":[{"meta":{"regularMarketPrice":123.45}}],"error":null}}"#
assert(parseQuotePrice(Data(quoteJSON.utf8)) == Decimal(123.45))
assert(parseQuotePrice(Data(#"{"chart":{"result":[]}}"#.utf8)) == nil)
assert(parseQuotePrice(Data("garbage".utf8)) == nil)

// groupHoldings: same symbol merges and sums; different symbols stay separate
let lot1 = Holding(kind: "ETF", name: "0050", symbol: "0050.TW", quantity: 1000, costPerUnit: 100, currentPrice: 120)
let lot2 = Holding(kind: "ETF", name: "0050", symbol: "0050.TW", quantity: 500, costPerUnit: 110, currentPrice: 120)
let lot3 = Holding(kind: "US Stocks", name: "Apple", symbol: "AAPL", quantity: 10, costPerUnit: 150, currentPrice: 170)
let groups = groupHoldings([lot1, lot2, lot3])
assert(groups.count == 2)
assert(groups[0].symbol == "0050.TW" && groups[0].lots.count == 2)
assert(groups[0].shares == 1500)
assert(groups[0].cost == 155000)          // 1000*100 + 500*110
assert(groups[0].marketValue == 180000)   // 1500*120
assert(groups[0].gain == 25000)
assert(groups[1].symbol == "AAPL" && groups[1].lots.count == 1)

// goldTWDPerTael: USD/oz × USD→TWD, oz→兩 conversion. 2000 × 32 / 31.1035 × 37.5
let goldTael = goldTWDPerTael(usdPerOz: 2000, usdTwd: 32)
assert(goldTael > 77000 && goldTael < 78000)   // ≈ 77,161

// parseChartSeries: pull daily (date, close) out of Yahoo chart JSON, skip nulls
let chartJSON = #"{"chart":{"result":[{"timestamp":[1000,1086400,1172800],"indicators":{"quote":[{"close":[100.0,null,120.0]}]}}]}}"#
let ser = parseChartSeries(Data(chartJSON.utf8))
assert(ser.count == 2)   // the null is skipped
assert(ser[0].close == Decimal(100) && ser[1].close == Decimal(120))
assert(parseChartSeries(Data("garbage".utf8)).isEmpty)

// portfolioSeries: bought on day 2 of a 3-day window; 0 before, qty×close after
var pcal = Calendar(identifier: .gregorian)
pcal.timeZone = TimeZone(identifier: "America/New_York")!
let d1 = day(2026, 6, 1), d2 = day(2026, 6, 2), d3 = day(2026, 6, 3)
let hist: [String: [(date: Date, close: Decimal)]] = ["AAPL": [(d1, 100), (d2, 110), (d3, 120)]]
let buy = Holding(kind: "US Stocks", name: "Apple", symbol: "AAPL", quantity: 10,
                  costPerUnit: 100, currentPrice: 120, date: d2)
let pser = portfolioSeries(holdings: [buy], history: hist, days: 3, endingAt: d3, calendar: pcal)
assert(pser.count == 3)
assert(pser[0].value == 0)        // day1: not yet bought
assert(pser[1].value == 1100)     // day2: 10 × 110
assert(pser[2].value == 1200)     // day3: 10 × 120

// reduceLots: sell 12 of 15 (10 bought d1 + 5 bought d2) FIFO → first lot gone,
// second reduced to 3; buy cost basis preserved on the survivor.
let sellLotA = Holding(kind: "US Stocks", name: "T", symbol: "T", quantity: 10, costPerUnit: 100, currentPrice: 120, date: day(2026, 6, 1))
let sellLotB = Holding(kind: "US Stocks", name: "T", symbol: "T", quantity: 5, costPerUnit: 110, currentPrice: 120, date: day(2026, 6, 2))
let afterSell = reduceLots([sellLotA, sellLotB], by: 12)
assert(afterSell.count == 1)
assert(afterSell[0].id == sellLotB.id && afterSell[0].quantity == 3)
assert(afterSell[0].costPerUnit == 110)
assert(afterSell.reduce(Decimal(0)) { $0 + $1.quantity } == 3)
// selling everything leaves no lots
assert(reduceLots([sellLotA, sellLotB], by: 15).isEmpty)
// selling less than the first lot only shrinks it, keeps the second intact
let partial = reduceLots([sellLotA, sellLotB], by: 4)
assert(partial.count == 2 && partial[0].quantity == 6 && partial[1].quantity == 5)

// chartYDomain: pads a real range, and never returns a zero-height range (flat /
// empty data) — a zero range makes Swift Charts emit "Invalid frame dimension".
let dom = chartYDomain([100, 200])
assert(dom.lowerBound < 100 && dom.upperBound > 200)       // padded outward
assert(chartYDomain([50, 50]) == 49.0...51.0)              // flat -> ±1, not zero
assert(chartYDomain([]).lowerBound < chartYDomain([]).upperBound)  // empty -> non-degenerate

// changePct
assert(abs(changePct(120, 100) - 20) < 0.001)
assert(changePct(120, 0) == 0)

print("all DayMath tests passed")

print("all money tests passed")
