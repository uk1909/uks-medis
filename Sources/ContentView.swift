import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var meds: [Medication]

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Heute", systemImage: "clock") }
            MedicationListView()
                .tabItem { Label("Medikamente", systemImage: "pills") }
            PlanExportView()
                .tabItem { Label("Plan", systemImage: "doc.text") }
        }
        .tint(.teal)
        .onAppear {
            NotificationManager.shared.rescheduleAll(meds)
        }
    }
}
