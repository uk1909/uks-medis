import SwiftUI
import SwiftData
import PDFKit

struct PlanExportView: View {
    @Query(sort: \Medication.name) private var meds: [Medication]

    @AppStorage("patientName") private var patientName: String = ""
    @AppStorage("patientCity") private var patientCity: String = ""
    @AppStorage("patientBirth") private var patientBirth: Double = -315_619_200 // 01.01.1960
    @AppStorage("patientHasBirth") private var hasBirth: Bool = false

    @State private var pdfURL: URL?

    private var birthBinding: Binding<Date> {
        Binding<Date>(
            get: { Date(timeIntervalSince1970: patientBirth) },
            set: { newValue in
                patientBirth = newValue.timeIntervalSince1970
                hasBirth = true
                pdfURL = nil
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, Vorname", text: $patientName)
                        .textContentType(.name)
                    TextField("Wohnort", text: $patientCity)
                        .textContentType(.addressCity)
                    DatePicker("Geburtsdatum", selection: birthBinding, in: ...Date(), displayedComponents: .date)
                } header: {
                    Text("Patientendaten")
                } footer: {
                    Text("Die Angaben werden nur auf deinem iPhone gespeichert und erscheinen im Kopf des Plans.")
                }

                Section {
                    Button {
                        createPDF()
                    } label: {
                        Label("Medikationsplan als PDF erstellen", systemImage: "doc.richtext")
                    }
                } footer: {
                    Text("Enthält \(meds.count) Einträge: regelmäßige Medikamente, Bei-Bedarf-Medikamente und Hilfsmittel.")
                }

                if let url = pdfURL {
                    Section("Vorschau") {
                        PDFPreview(url: url)
                            .frame(height: 260)
                            .listRowInsets(EdgeInsets())
                        ShareLink(item: url) {
                            Label("Teilen, drucken oder in Dateien sichern", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Medikationsplan")
            .onChange(of: patientName) { pdfURL = nil }
            .onChange(of: patientCity) { pdfURL = nil }
        }
    }

    private func createPDF() {
        let info = PatientInfo(
            name: patientName.trimmingCharacters(in: .whitespaces),
            city: patientCity.trimmingCharacters(in: .whitespaces),
            birthDate: hasBirth ? Date(timeIntervalSince1970: patientBirth) : nil
        )
        let data: Data = PlanPDF.render(meds: meds, patient: info)

        let rawName: String = info.name.isEmpty ? "Medikationsplan" : "Medikationsplan " + info.name
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let safeName: String = String(rawName.unicodeScalars.filter { allowed.contains($0) })
        let url: URL = FileManager.default.temporaryDirectory.appendingPathComponent(safeName + ".pdf")
        do {
            try data.write(to: url, options: .atomic)
            pdfURL = nil
            DispatchQueue.main.async { pdfURL = url }
        } catch {
            pdfURL = nil
        }
    }
}

struct PDFPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
