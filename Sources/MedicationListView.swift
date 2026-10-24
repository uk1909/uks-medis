import SwiftUI
import SwiftData

struct MedicationListView: View {
    @Query(sort: \Medication.name) private var meds: [Medication]
    @Environment(\.modelContext) private var context
    @State private var showAdd = false
    @State private var editing: Medication?

    var body: some View {
        NavigationStack {
            List {
                ForEach(meds) { med in
                    Button { editing = med } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(med.name).font(.headline)
                            if !med.dosage.isEmpty {
                                Text(med.dosage).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Text(detailText(med))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.teal)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if meds.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Einträge",
                        systemImage: "pills",
                        description: Text("Tippe auf +, um ein Medikament oder Hilfsmittel hinzuzufügen.")
                    )
                }
            }
            .navigationTitle("Medikamente")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                MedicationEditView(medication: nil)
            }
            .sheet(item: $editing) { med in
                MedicationEditView(medication: med)
            }
        }
    }

    private func detailText(_ med: Medication) -> String {
        var parts: [String] = []
        if med.isAid { parts.append("Hilfsmittel") }
        parts.append(med.scheduleText)
        if !med.asNeeded { parts.append(timesText(med)) }
        return parts.joined(separator: " · ")
    }

    private func timesText(_ med: Medication) -> String {
        let sorted: [Int] = med.times.sorted()
        let parts: [String] = sorted.map { Medication.timeString($0) }
        return parts.joined(separator: " · ")
    }

    private func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { meds[$0] }
        let remaining = meds.filter { m in !toDelete.contains { $0.id == m.id } }
        toDelete.forEach { context.delete($0) }
        try? context.save()
        NotificationManager.shared.rescheduleAll(remaining)
    }
}
