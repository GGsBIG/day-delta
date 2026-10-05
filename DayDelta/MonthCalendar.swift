import SwiftUI

/// Month header + weekday row + day grid for the Ledger. Days with any txn show
/// a dot colored by that day's largest-amount category. Today is ringed; the
/// selected day is filled.
struct MonthCalendarView: View {
    let monthAnchor: Date
    let txns: [Txn]
    let categories: [Category]
    @Binding var selectedDay: Date
    let onPrevMonth: () -> Void
    let onNextMonth: () -> Void

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayRow
            grid
        }
        .padding(.horizontal, 4)
    }

    private var header: some View {
        HStack {
            Button(action: onPrevMonth) { Image(systemName: "chevron.left") }
            Spacer()
            Text(monthTitle)
                .font(.system(.headline, design: .rounded))
            Spacer()
            Button(action: onNextMonth) { Image(systemName: "chevron.right") }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.calendar = cal
        f.locale = .current
        f.dateFormat = "LLLL yyyy"
        return f.string(from: monthAnchor)
    }

    private var weekdayRow: some View {
        let symbols = orderedWeekdaySymbols()
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(symbols, id: \.self) { s in
                Text(s).font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.gray)
            }
        }
    }

    /// Very-short weekday symbols rotated to start at `calendar.firstWeekday`.
    private func orderedWeekdaySymbols() -> [String] {
        let base = cal.veryShortStandaloneWeekdaySymbols   // index 0 = Sunday
        let start = cal.firstWeekday - 1
        return (0..<7).map { base[($0 + start) % 7] }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<leadingBlanks(forMonthContaining: monthAnchor, calendar: cal), id: \.self) { _ in
                Color.clear.frame(height: 40)
            }
            ForEach(daysInMonth(containing: monthAnchor, calendar: cal), id: \.self) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let dayTxns = txnsOn(txns, day: day, calendar: cal)
        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(day)
        let dotColor = dominantCategoryID(dayTxns)
            .flatMap { id in categories.first { $0.id == id } }
            .map { Color(hex: $0.colorHex) }
        return Button {
            selectedDay = cal.startOfDay(for: day)
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(isSelected ? .black : .white)
                Circle()
                    .fill(dotColor ?? .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isToday && !isSelected ? Color.white.opacity(0.5) : .clear,
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
