import Foundation
import UserNotifications

/// Local notifications for events with `notify == true`, fired at 09:00 on the
/// event's day (repeating on the recurrence for recurring events).
enum Notifications {
    static func requestAuthIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Rebuild every DayDelta notification from the current events. Idempotent:
    /// clears all pending requests, then re-adds the ones that should exist.
    static func sync(_ events: [Event], calendar: Calendar = .current) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for event in events where event.notify {
            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = "It's the day."
            content.sound = .default

            let trigger: UNCalendarNotificationTrigger
            switch event.recurrence {
            case .none:
                var dc = calendar.dateComponents([.year, .month, .day], from: event.targetDate)
                dc.hour = 9; dc.minute = 0
                guard let fire = calendar.date(from: dc), fire > Date() else { continue }
                trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
            case .yearly:
                var dc = calendar.dateComponents([.month, .day], from: event.targetDate)
                dc.hour = 9; dc.minute = 0
                trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            case .monthly:
                var dc = calendar.dateComponents([.day], from: event.targetDate)
                dc.hour = 9; dc.minute = 0
                trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            case .weekly:
                var dc = calendar.dateComponents([.weekday], from: event.targetDate)
                dc.hour = 9; dc.minute = 0
                trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            }

            center.add(UNNotificationRequest(identifier: event.id.uuidString,
                                             content: content, trigger: trigger))
        }
    }
}
