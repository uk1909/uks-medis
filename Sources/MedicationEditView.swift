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
    @State private var loaded = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !times.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medikament") {
                    TextField("Name (z. B. Ibuprofen)", text: $name)
                    TextField("Dosierung (z. B. 1 Tablette, 400 mg)", text: $dosage)
                    TextField("Hinweis (z. B. zum Essen)", text: $note)
                }

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
                    Text("Zu jeder Uhrzeit bekommst du täglich eine Push-Erinnerung. Zum Entfernen einer Uhrzeit nach links wischen.")
                }

                if medication != nil {
                    Section {
                        Button("Medikament löschen", role: .destructive, action: deleteMedication)
                    }
                }
            }
            .navigationTitle(medication == nil ? "Neues Medikament" : "Bearbeiten")
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
        } else {
            times = [TimeEntry(date: Medication.date(fromMinutes: 8 * 60))]
        }
    }

    private func suggestedNextTime() -> Int {
        guard let last = times.map({ Medication.minutes(from: $0.date) }).max() else { return 8 * 60 }
        return min(last + 4 * 60, 22 * 60)
    }

    private func save() {
        let minutes = Array(Set(times.map { Medication.minutes(from: $0.date) })).sorted()
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let m = medication {
            m.name = trimmedName
            m.dosage = dosage
            m.note = note
            m.times = minutes
        } else {
            context.insert(Medication(name: trimmedName, dosage: dosage, note: note, times: minutes))
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
