import SwiftUI
import SwiftData

private struct TimeEntry: Identifiable {
    let id = UUID()
    var date: Date
}

struct MedicationEditView: View {
    let medication: Medication?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var dosage = ""
    @State private var note = ""
    @State private var times: [TimeEntry] = []
    /// 0 = täglich, 1 = bestimmte Wochentage, 2 = bei Bedarf
    @State private var mode: Int = 0
    @State private var isAid = false
    @State private var weekdays: Set<Int> = []
    @State private var loaded = false

    private var canSave: Bool {
        let hasName: Bool = !name.trimmingCharacters(in: .whitespaces).isEmpty
        if mode == 2 { return hasName }
        let hasDays: Bool = mode == 0 || !weekdays.isEmpty
        return hasName && !times.isEmpty && hasDays
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Art", selection: $isAid) {
                        Text("Medikament").tag(false)
                        Text("Hilfsmittel").tag(true)
                    }
                    .pickerStyle(.segmented)
                    TextField(isAid ? "Name (z. B. Dexcom G7 Sensor)" : "Name (z. B. Ibuprofen, Insulin)", text: $name)
                    TextField("Dosierung (z. B. 1 Tablette, 400 mg)", text: $dosage)
                    TextField("Hinweis (z. B. zum Essen)", text: $note)
                } header: {
                    Text("Eintrag")
                }

                Section {
                    Picker("Rhythmus", selection: $mode) {
                        Text("Täglich").tag(0)
                        Text("Wochentage").tag(1)
                        Text("Bei Bedarf").tag(2)
                    }
                    .pickerStyle(.segmented)

                    if mode == 1 {
                        WeekdayPicker(selection: $weekdays)
                    }
                } header: {
                    Text("Wie oft?")
                } footer: {
                    if mode == 1 {
                        Text("Für einmal pro Woche einfach nur einen Tag antippen.")
                    } else if mode == 2 {
                        Text("Ohne feste Zeiten und ohne Erinnerung. Erscheint auf „Heute“ unter „Bei Bedarf & Hilfsmittel“.")
                    }
                }

                if mode != 2 {
                Section {
                    ForEach($times) { $entry in
                        DatePicker("Einnahme", selection: $entry.date, displayedComponents: .hourAndMinute)
                    }
                    .onDelete { times.remove(atOffsets: $0) }

                    Button {
                        times.append(TimeEntry(date: Medication.date(fromMinutes: suggestedNextTime())))
                    } label: {
                        Label("Uhrzeit hinzufügen", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Einnahmezeiten")
                } footer: {
                    Text("Zu jeder Uhrzeit bekommst du an den gewählten Tagen eine Push-Erinnerung. Zum Entfernen einer Uhrzeit nach links wischen.")
                }
                }

                if medication != nil {
                    Section {
                        Button("Eintrag löschen", role: .destructive, action: deleteMedication)
                    }
                }
            }
            .navigationTitle(medication == nil ? "Neuer Eintrag" : "Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let m = medication {
            name = m.name
            dosage = m.dosage
            note = m.note
            times = m.times.sorted().map { TimeEntry(date: Medication.date(fromMinutes: $0)) }
            isAid = m.isAid
            weekdays = Set(m.weekdays)
            if m.asNeeded {
                mode = 2
            } else if m.weekdays.isEmpty {
                mode = 0
            } else {
                mode = 1
            }
            if times.isEmpty {
                times = [TimeEntry(date: Medication.date(fromMinutes: 8 * 60))]
            }
        } else {
            times = [TimeEntry(date: Medication.date(fromMinutes: 8 * 60))]
        }
    }

    private func suggestedNextTime() -> Int {
        guard let last = times.map({ Medication.minutes(from: $0.date) }).max() else { return 8 * 60 }
        return min(last + 4 * 60, 22 * 60)
    }

    private func save() {
        let asNeeded: Bool = mode == 2
        let allMinutes: [Int] = Array(Set(times.map { Medication.minutes(from: $0.date) })).sorted()
        let minutes: [Int] = asNeeded ? [] : allMinutes
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let days: [Int] = mode == 1 ? Array(weekdays).sorted() : []

        if let m = medication {
            m.name = trimmedName
            m.dosage = dosage
            m.note = note
            m.times = minutes
            m.weekdays = days
            m.asNeeded = asNeeded
            m.isAid = isAid
        } else {
            let med = Medication(name: trimmedName, dosage: dosage, note: note, times: minutes,
                                 weekdays: days, asNeeded: asNeeded, isAid: isAid)
            context.insert(med)
        }
        try? context.save()
        rescheduleNotifications()
        dismiss()
    }

    private func deleteMedication() {
        if let m = medication { context.delete(m) }
        try? context.save()
        rescheduleNotifications()
        dismiss()
    }

    private func rescheduleNotifications() {
        let all = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        NotificationManager.shared.rescheduleAll(all)
    }
}

/// Sieben runde Knöpfe Mo–So zum An-/Abwählen der Wochentage.
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Medication.weekdayOrder, id: \.self) { wd in
                dayButton(wd)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func dayButton(_ wd: Int) -> some View {
        let isOn: Bool = selection.contains(wd)
        let fill: Color = isOn ? Color.teal : Color.gray.opacity(0.15)
        let textColor: Color = isOn ? Color.white : Color.primary
        return Button {
            if isOn { selection.remove(wd) } else { selection.insert(wd) }
        } label: {
            Text(Medication.weekdayShortName(wd))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textColor)
                .frame(width: 38, height: 38)
                .background(Circle().fill(fill))
        }
        .buttonStyle(.plain)
    }
}
