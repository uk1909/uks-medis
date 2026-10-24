import UIKit

struct PatientInfo {
    var name: String
    var city: String
    var birthDate: Date?
}

/// Erzeugt einen Medikationsplan als PDF (A4 quer).
enum PlanPDF {
    static let pageRect = CGRect(x: 0, y: 0, width: 842, height: 595)

    static func render(meds: [Medication], patient: PatientInfo) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Medikationsplan",
            kCGPDFContextCreator as String: "uk's medis"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let sorted: [Medication] = meds.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        let regular: [Medication] = sorted.filter { !$0.isAid && !$0.asNeeded }
        let prn: [Medication] = sorted.filter { !$0.isAid && $0.asNeeded }
        let aids: [Medication] = sorted.filter { $0.isAid }

        return renderer.pdfData { ctx in
            let drawer = PlanPageDrawer(ctx: ctx, patient: patient, pageRect: pageRect)
            drawer.beginPage()
            drawer.section(title: "Regelmäßige Medikamente", rows: regular.map { PlanPDF.row($0) })
            drawer.section(title: "Bei Bedarf", rows: prn.map { PlanPDF.row($0) })
            drawer.section(title: "Hilfsmittel", rows: aids.map { PlanPDF.row($0) })
            if sorted.isEmpty {
                drawer.note("Es sind noch keine Medikamente eingetragen.")
            }
        }
    }

    /// 0 = morgens, 1 = mittags, 2 = abends, 3 = zur Nacht
    static func bucket(_ minutes: Int) -> Int {
        if minutes < 11 * 60 { return 0 }
        if minutes < 15 * 60 { return 1 }
        if minutes < 21 * 60 { return 2 }
        return 3
    }

    static func row(_ med: Medication) -> [String] {
        var buckets: [[String]] = [[], [], [], []]
        for t in med.times.sorted() {
            buckets[bucket(t)].append(Medication.timeString(t))
        }
        let cells: [String] = buckets.map { $0.joined(separator: "\n") }
        return [med.name, med.dosage, cells[0], cells[1], cells[2], cells[3], med.scheduleText, med.note]
    }
}

final class PlanPageDrawer {
    private let ctx: UIGraphicsPDFRendererContext
    private let patient: PatientInfo
    private let pageRect: CGRect
    private let margin: CGFloat = 36
    private var y: CGFloat = 0
    private var page: Int = 0

    private let titles: [String] = ["Medikament / Hilfsmittel", "Dosierung", "Morgens", "Mittags",
                                    "Abends", "Zur Nacht", "Rhythmus", "Hinweise"]
    private let widths: [CGFloat] = [170, 110, 60, 60, 60, 60, 100, 150]
    private let centered: Set<Int> = [2, 3, 4, 5]

    private let accent = UIColor(red: 0.05, green: 0.45, blue: 0.56, alpha: 1)
    private let lineColor = UIColor(white: 0.78, alpha: 1)
    private let headerFill = UIColor(red: 0.90, green: 0.95, blue: 0.96, alpha: 1)

    private var bottom: CGFloat { pageRect.height - margin - 24 }

    init(ctx: UIGraphicsPDFRendererContext, patient: PatientInfo, pageRect: CGRect) {
        self.ctx = ctx
        self.patient = patient
        self.pageRect = pageRect
    }

    // MARK: - Seiten

    func beginPage() {
        ctx.beginPage()
        page += 1
        drawHeader()
        drawFooter()
    }

    private func drawHeader() {
        let contentWidth: CGFloat = pageRect.width - 2 * margin
        draw("Medikationsplan", font: .boldSystemFont(ofSize: 22), color: accent,
             in: CGRect(x: margin, y: margin, width: 400, height: 28))

        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "dd.MM.yyyy"
        let stand: String = "Stand: " + df.string(from: Date())
        draw(stand, font: .systemFont(ofSize: 10), color: .darkGray,
             in: CGRect(x: margin, y: margin + 8, width: contentWidth, height: 14), align: .right)

        // Patientenkasten
        let boxY: CGFloat = margin + 34
        let box = CGRect(x: margin, y: boxY, width: contentWidth, height: 40)
        let path = UIBezierPath(roundedRect: box, cornerRadius: 6)
        accent.setStroke()
        path.lineWidth = 1
        path.stroke()

        let birth: String = patient.birthDate.map { df.string(from: $0) } ?? ""
        let fields: [(String, String)] = [
            ("Patient/in", patient.name),
            ("Geburtsdatum", birth),
            ("Wohnort", patient.city)
        ]
        let colWidth: CGFloat = (contentWidth - 24) / 3
        for (i, field) in fields.enumerated() {
            let x: CGFloat = margin + 12 + CGFloat(i) * colWidth
            draw(field.0, font: .systemFont(ofSize: 8), color: .gray,
                 in: CGRect(x: x, y: boxY + 6, width: colWidth - 8, height: 10))
            let value: String = field.1.isEmpty ? "–" : field.1
            draw(value, font: .boldSystemFont(ofSize: 12), color: .black,
                 in: CGRect(x: x, y: boxY + 18, width: colWidth - 8, height: 16))
        }
        y = boxY + 40 + 18
    }

    private func drawFooter() {
        let contentWidth: CGFloat = pageRect.width - 2 * margin
        let fy: CGFloat = pageRect.height - margin - 10
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: fy - 6))
        line.addLine(to: CGPoint(x: pageRect.width - margin, y: fy - 6))
        lineColor.setStroke()
        line.lineWidth = 0.5
        line.stroke()
        draw("Erstellt mit uk's medis · Bitte zu jedem Arzt- und Apothekenbesuch mitbringen.",
             font: .systemFont(ofSize: 8), color: .gray,
             in: CGRect(x: margin, y: fy, width: contentWidth, height: 12))
        draw("Seite \(page)", font: .systemFont(ofSize: 8), color: .gray,
             in: CGRect(x: margin, y: fy, width: contentWidth, height: 12), align: .right)
    }

    // MARK: - Tabelle

    func section(title: String, rows: [[String]]) {
        if rows.isEmpty { return }
        let firstHeight: CGFloat = rowHeight(rows[0], font: cellFont)
        if y + 20 + 22 + firstHeight > bottom { beginPage() }
        drawSectionTitle(title)
        drawTableHeader()
        for r in rows {
            let h: CGFloat = rowHeight(r, font: cellFont)
            if y + h > bottom {
                beginPage()
                drawSectionTitle(title + " (Fortsetzung)")
                drawTableHeader()
            }
            drawRow(r, height: h)
        }
        y += 14
    }

    func note(_ text: String) {
        draw(text, font: .italicSystemFont(ofSize: 11), color: .darkGray,
             in: CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 16))
        y += 20
    }

    private var cellFont: UIFont { .systemFont(ofSize: 10) }

    private func drawSectionTitle(_ title: String) {
        draw(title, font: .boldSystemFont(ofSize: 12), color: accent,
             in: CGRect(x: margin, y: y, width: 500, height: 16))
        y += 20
    }

    private func drawTableHeader() {
        let total: CGFloat = widths.reduce(0, +)
        let rect = CGRect(x: margin, y: y, width: total, height: 20)
        headerFill.setFill()
        UIBezierPath(rect: rect).fill()
        var x: CGFloat = margin
        for i in 0..<titles.count {
            let align: NSTextAlignment = centered.contains(i) ? .center : .left
            draw(titles[i], font: .boldSystemFont(ofSize: 9), color: .black,
                 in: CGRect(x: x + 4, y: y + 5, width: widths[i] - 8, height: 12), align: align)
            x += widths[i]
        }
        y += 20
        drawLine(at: y)
    }

    private func rowHeight(_ cells: [String], font: UIFont) -> CGFloat {
        var maxH: CGFloat = 12
        for i in 0..<cells.count {
            let h: CGFloat = textHeight(cells[i], font: font, width: widths[i] - 8)
            if h > maxH { maxH = h }
        }
        return maxH + 10
    }

    private func drawRow(_ cells: [String], height: CGFloat) {
        var x: CGFloat = margin
        for i in 0..<cells.count {
            let isName: Bool = i == 0
            let font: UIFont = isName ? .boldSystemFont(ofSize: 10) : cellFont
            let align: NSTextAlignment = centered.contains(i) ? .center : .left
            draw(cells[i], font: font, color: .black,
                 in: CGRect(x: x + 4, y: y + 5, width: widths[i] - 8, height: height - 6), align: align)
            x += widths[i]
        }
        y += height
        drawLine(at: y)
    }

    private func drawLine(at lineY: CGFloat) {
        let total: CGFloat = widths.reduce(0, +)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: lineY))
        path.addLine(to: CGPoint(x: margin + total, y: lineY))
        lineColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    // MARK: - Text

    private func attributes(font: UIFont, color: UIColor, align: NSTextAlignment) -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.alignment = align
        p.lineBreakMode = .byWordWrapping
        return [.font: font, .foregroundColor: color, .paragraphStyle: p]
    }

    private func draw(_ text: String, font: UIFont, color: UIColor, in rect: CGRect,
                      align: NSTextAlignment = .left) {
        let attrs = attributes(font: font, color: color, align: align)
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
    }

    private func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        if text.isEmpty { return 0 }
        let attrs = attributes(font: font, color: .black, align: .left)
        let size = CGSize(width: width, height: .greatestFiniteMagnitude)
        let r: CGRect = (text as NSString).boundingRect(with: size, options: [.usesLineFragmentOrigin],
                                                        attributes: attrs, context: nil)
        return ceil(r.height)
    }
}
