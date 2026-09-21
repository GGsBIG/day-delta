import Foundation

/// Whole-day difference between two dates, each normalized to start-of-day.
/// Positive = target in the future (countdown), negative = past (count-up), 0 = today.
/// Normalizing both to startOfDay first avoids the off-by-one where a sub-24h
/// gap would otherwise round to 0.
func dayDelta(to target: Date, from now: Date = Date(), calendar: Calendar = .current) -> Int {
    let a = calendar.startOfDay(for: now)
    let b = calendar.startOfDay(for: target)
    return calendar.dateComponents([.day], from: a, to: b).day ?? 0
}

/// Big number + subtitle.
/// Future date → countdown ("N" / "days left").
/// Today or past → day-together counter: the start day is day 1, so a date
/// that is `k` days in the past shows day `k + 1` ("N" / "days together").
func deltaText(_ delta: Int) -> (number: String, subtitle: String) {
    if delta > 0 { return ("\(delta)", "days left") }
    return ("\(-delta + 1)", "days together")
}
