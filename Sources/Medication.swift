import Foundation
import SwiftData

@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    var dosage: String = ""
    var note: String = ""
    /// Einnahmezeiten als Minuten seit Mitternacht (z. B. 8:30 = 510)
    var times: [Int] = []
    /// Erledigte Einnahmen, Schlüssel "yyyy-MM-dd|Minuten"
    var takenLog: [String] = []
    var createdAt: Date = Date()
    /// Wochentage der Einnahme (1 = Sonntag … 7 = Samstag, wie Calendar).
    /// Leer = täglich.
    var weekdays: [Int] = []
    /// Ohne festen Rhythmus (z. B. Insulin, Sensorwechsel) – keine Erinnerungen
    var asNeeded: Bool = false
    /// Hilfsmittel statt Medikament (z. B. Dexcom G7 Sensor)
    var isAid: Bool = false
    /// Zeitpunkte, an denen ein Bei-Bedarf-Eintrag genommen/gewechselt wurde
    var usageLog: [Date] = []

    init(name: String, dosage: String, note: String, times: [Int], weekdays: [Int] = [],
         asNeeded: Bool = false, isAid: Bool = false) {
        self.id = UUID()
        self.name = name
        self.dosage = dosage
        self.note = note
        self.times = times
        self.weekdays = weekdays
        self.asNeeded = asNeeded
        self.isAid = isAid
        self.createdAt = Date()
    }

    // MARK: - Rhythmus

    var isDaily: Bool { weekdays.isEmpty }

    /// Muss das Medikament an diesem Tag genommen werden?
    func isDue(on day: Date) -> Bool {
        if asNeeded { return false }
        if weekdays.isEmpty { return true }
        let wd: Int = Calendar.current.component(.weekday, from: day)
        return weekdays.contains(wd)
    }

    /// z. B. "Täglich", "Jeden Montag", "Mo, Mi, Fr"
    var scheduleText: String {
        if asNeeded { return "Bei Bedarf" }
        if weekdays.isEmpty { return "Täglich" }
        let sorted: [Int] = Medication.weekdayOrder.filter { weekdays.contains($0) }
        if sorted.count == 1 {
            return "Jeden " + Medication.weekdayLongName(sorted[0])
        }
        if sorted.count == 7 { return "Täglich" }
        let names: [String] = sorted.map { Medication.weekdayShortName($0) }
        return names.joined(separator: ", ")
    }

    // MARK: - Bei Bedarf erfassen

    var lastUsed: Date? { usageLog.max() }

    func logUsage(at date: Date) {
        usageLog.append(date)
        if usageLog.count > 300 {
            usageLog.sort()
            usageLog.removeFirst(usageLog.count - 300)
        }
    }

    func undoLastUsage() {
        guard let last = usageLog.max(), let i = usageLog.firstIndex(of: last) else { return }
        usageLog.remove(at: i)
    }

    func usageCount(on day: Date) -> Int {
        let cal = Calendar.current
        return usageLog.filter { cal.isDate($0, inSameDayAs: day) }.count
    }

    // MARK: - Einnahme abhaken

    func isTaken(minutes: Int, on day: Date) -> Bool {
        takenLog.contains(Self.logKey(day: day, minutes: minutes))
    }

    func toggleTaken(minutes: Int, on day: Date) {
        let key = Self.logKey(day: day, minutes: minutes)
        if let i = takenLog.firstIndex(of: key) {
            takenLog.remove(at: i)
        } else {
            takenLog.append(key)
        }
        pruneLog()
    }

    /// Alte Einträge (älter als 30 Tage) entfernen
    private func pruneLog() {
        guard let limit = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return }
        let limitString = Self.dayFormatter.string(from: limit)
        takenLog.removeAll { $0.prefix(10) < limitString }
    }
}

// Hilfsfunktionen außerhalb des @Model-Körpers
extension Medication {
    // MARK: - Hilfsfunktionen

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func logKey(day: Date, minutes: Int) -> String {
        "\(dayFormatter.string(from: day))|\(minutes)"
    }

    static func minutes(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func date(fromMinutes m: Int) -> Date {
        Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
    }

    /// Montag zuerst (deutsche Reihenfolge)
    static let weekdayOrder: [Int] = [2, 3, 4, 5, 6, 7, 1]

    static func weekdayShortName(_ wd: Int) -> String {
        let names: [String] = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
        return names[(wd - 1) % 7]
    }

    static func weekdayLongName(_ wd: Int) -> String {
        let names: [String] = ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"]
        return names[(wd - 1) % 7]
    }

    static func timeString(_ m: Int) -> String {
        String(format: "%02d:%02d", m / 60, m % 60)
    }
}
