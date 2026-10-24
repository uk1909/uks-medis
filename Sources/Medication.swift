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

    init(name: String, dosage: String, note: String, times: [Int]) {
        self.id = UUID()
        self.name = name
        self.dosage = dosage
        self.note = note
        self.times = times
        self.createdAt = Date()
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

    static func timeString(_ m: Int) -> String {
        String(format: "%02d:%02d", m / 60, m % 60)
    }
}
