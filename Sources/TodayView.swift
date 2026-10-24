import SwiftUI
import SwiftData

struct Dose: Identifiable {
    let med: Medication
    let minutes: Int
    var id: String { "\(med.id.uuidString)-\(minutes)" }
}

enum DayPart: CaseIterable, Identifiable {
    case morning, noon, afternoon, evening
    var id: Self { self }

    var title: String {
        switch self {
        case .morning: "Morgens"
        case .noon: "Mittags"
        case .afternoon: "Nachmittags"
        case .evening: "Abends"
        }
    }

    var icon: String {
        switch self {
        case .morning: "sunrise"
        case .noon: "sun.max"
        case .afternoon: "sun.min"
        case .evening: "moon.stars"
        }
    }

    func contains(_ m: Int) -> Bool {
        switch self {
        case .morning: m < 11 * 60
        case .noon: m >= 11 * 60 && m < 14 * 60
        case .afternoon: m >= 14 * 60 && m < 18 * 60
        case .evening: m >= 18 * 60
        }
    }
}

struct TodayView: View {
    @Query(sort: \Medication.name) private var meds: [Medication]
    @State private var now = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var doses: [Dose] {
        var result: [Dose] = []
        for med in meds where med.isDue(on: now) {
            for minutes in Set(med.times) {
                result.append(Dose(med: med, minutes: minutes))
            }
        }
        result.sort { (a: Dose, b: Dose) -> Bool in
            if a.minutes != b.minutes { return a.minutes < b.minutes }
            return a.med.name < b.med.name
        }
        return result
    }

    private var asNeededMeds: [Medication] { meds.filter { $0.asNeeded } }

    private var nowMinutes: Int { Medication.minutes(from: now) }

    private var nextDose: Dose? {
        doses.first { $0.minutes >= nowMinutes && !$0.med.isTaken(minutes: $0.minutes, on: now) }
    }

    private var takenCount: Int {
        doses.filter { $0.med.isTaken(minutes: $0.minutes, on: now) }.count
    }

    private func subtitle(for dose: Dose) -> String {
        let time: String = Medication.timeString(dose.minutes)
        if dose.med.dosage.isEmpty { return "um \(time) Uhr" }
        return "um \(time) Uhr · \(dose.med.dosage)"
    }

    var body: some View {
        NavigationStack {
            List {
                if !doses.isEmpty {
                    Section {
                        ProgressView(value: Double(takenCount), total: Double(doses.count)) {
                            Text("\(takenCount) von \(doses.count) Einnahmen erledigt")
                                .font(.subheadline)
                        }
                        .tint(.teal)
                    }

                    if let next = nextDose {
                        Section("Als Nächstes") {
                            HStack(spacing: 14) {
                                Image(systemName: "bell.badge.fill")
                                    .font(.title2)
                                    .foregroundStyle(.teal)
                                VStack(alignment: .leading) {
                                    Text(next.med.name).font(.headline)
                                    Text(subtitle(for: next))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    ForEach(DayPart.allCases) { part in
                        let items = doses.filter { part.contains($0.minutes) }
                        if !items.isEmpty {
                            Section {
                                ForEach(items) { dose in
                                    DoseRow(dose: dose, now: now, nowMinutes: nowMinutes)
                                }
                            } header: {
                                Label(part.title, systemImage: part.icon)
                            }
                        }
                    }
                }

                if !asNeededMeds.isEmpty {
                    Section {
                        ForEach(asNeededMeds) { med in
                            AsNeededRow(med: med, now: now)
                        }
                    } header: {
                        Label("Bei Bedarf & Hilfsmittel", systemImage: "cross.case")
                    } footer: {
                        Text("Tippe auf den Knopf, wenn du etwas genommen oder gewechselt hast. Zum Rückgängigmachen nach links wischen.")
                    }
                }
            }
            .overlay {
                if meds.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Medikamente",
                        systemImage: "pills",
                        description: Text("Füge im Tab „Medikamente“ dein erstes Medikament hinzu.")
                    )
                } else if doses.isEmpty && asNeededMeds.isEmpty {
                    ContentUnavailableView(
                        "Heute nichts einzunehmen",
                        systemImage: "checkmark.seal",
                        description: Text("Für heute sind keine Medikamente geplant.")
                    )
                }
            }
            .navigationTitle("Heute")
            .onReceive(timer) { now = $0 }
        }
    }
}

struct DoseRow: View {
    let dose: Dose
    let now: Date
    let nowMinutes: Int

    var body: some View {
        let taken = dose.med.isTaken(minutes: dose.minutes, on: now)
        let overdue = !taken && dose.minutes < nowMinutes

        Button {
            withAnimation { dose.med.toggleTaken(minutes: dose.minutes, on: now) }
        } label: {
            HStack(spacing: 14) {
                Text(Medication.timeString(dose.minutes))
                    .font(.system(.body, design: .rounded).monospacedDigit().bold())
                    .foregroundStyle(overdue ? Color.red : Color.primary)
                    .frame(width: 56, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(dose.med.name)
                        .font(.body.weight(.semibold))
                        .strikethrough(taken)
                        .foregroundStyle(taken ? Color.secondary : Color.primary)
                    if !dose.med.dosage.isEmpty {
                        Text(dose.med.dosage).font(.caption).foregroundStyle(.secondary)
                    }
                    if overdue {
                        Text("Noch nicht genommen").font(.caption2).foregroundStyle(.red)
                    }
                }

                Spacer()

                Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(taken ? Color.teal : Color.gray)
            }
        }
        .buttonStyle(.plain)
    }
}

struct AsNeededRow: View {
    let med: Medication
    let now: Date

    private var lastText: String {
        guard let last = med.lastUsed else { return "Noch nicht erfasst" }
        let rel: String = last.formatted(.relative(presentation: .named))
        let abs: String = last.formatted(date: .abbreviated, time: .shortened)
        var text: String = "Zuletzt \(rel) (\(abs))"
        let count: Int = med.usageCount(on: now)
        if count > 1 { text += " · heute \(count)×" }
        return text
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: med.isAid ? "cross.case" : "pills")
                .font(.title3)
                .foregroundStyle(Color.teal)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(med.name).font(.body.weight(.semibold))
                if !med.dosage.isEmpty {
                    Text(med.dosage).font(.caption).foregroundStyle(.secondary)
                }
                Text(lastText).font(.caption2).foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation { med.logUsage(at: Date()) }
            } label: {
                Text(med.isAid ? "Gewechselt" : "Genommen")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.teal)
            .controlSize(.small)
        }
        .swipeActions(edge: .trailing) {
            if med.lastUsed != nil {
                Button(role: .destructive) {
                    withAnimation { med.undoLastUsage() }
                } label: {
                    Label("Rückgängig", systemImage: "arrow.uturn.backward")
                }
            }
        }
    }
}
