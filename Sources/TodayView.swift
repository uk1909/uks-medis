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
        meds.flatMap { m in Set(m.times).map { Dose(med: m, minutes: $0) } }
            .sorted { $0.minutes == $1.minutes ? $0.med.name < $1.med.name : $0.minutes < $1.minutes }
    }

    private var nowMinutes: Int { Medication.minutes(from: now) }

    private var nextDose: Dose? {
        doses.first { $0.minutes >= nowMinutes && !$0.med.isTaken(minutes: $0.minutes, on: now) }
    }

    private var takenCount: Int {
        doses.filter { $0.med.isTaken(minutes: $0.minutes, on: now) }.count
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
                                    Text("um \(Medication.timeString(next.minutes)) Uhr"
                                         + (next.med.dosage.isEmpty ? "" : " · \(next.med.dosage)"))
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
            }
            .overlay {
                if doses.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Medikamente",
                        systemImage: "pills",
                        description: Text("Füge im Tab „Medikamente“ dein erstes Medikament hinzu.")
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
                    .foregroundStyle(overdue ? .red : .primary)
                    .frame(width: 56, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(dose.med.name)
                        .font(.body.weight(.semibold))
                        .strikethrough(taken)
                        .foregroundStyle(taken ? .secondary : .primary)
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
                    .foregroundStyle(taken ? .teal : .gray)
            }
        }
        .buttonStyle(.plain)
    }
}
