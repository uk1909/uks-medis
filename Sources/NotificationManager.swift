import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Plant alle Erinnerungen neu (täglich wiederkehrend).
    func rescheduleAll(_ medications: [Medication]) {
        center.removeAllPendingNotificationRequests()

        for med in medications {
            for m in Set(med.times) {
                let content = UNMutableNotificationContent()
                content.title = "💊 \(med.name)"
                var body = med.dosage.isEmpty ? "Zeit für deine Einnahme." : "Zeit für \(med.dosage)."
                if !med.note.isEmpty { body += " – \(med.note)" }
                content.body = body
                content.sound = .default

                if med.weekdays.isEmpty {
                    schedule(content, id: "\(med.id.uuidString)-\(m)", minutes: m, weekday: nil)
                } else {
                    for wd in Set(med.weekdays) {
                        schedule(content, id: "\(med.id.uuidString)-\(m)-w\(wd)", minutes: m, weekday: wd)
                    }
                }
            }
        }
    }

    /// Wiederkehrender Hinweis: täglich (weekday = nil) oder wöchentlich am Wochentag.
    private func schedule(_ content: UNMutableNotificationContent, id: String, minutes m: Int, weekday: Int?) {
        var comps = DateComponents()
        comps.hour = m / 60
        comps.minute = m % 60
        if let weekday { comps.weekday = weekday }
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}
