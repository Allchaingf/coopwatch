//
//  ReportsView.swift  (Screen 11 — Reports)
//  CoopWatch
//
//  Compose a defence report (overview, risk-by-time, incidents, losses, fixed
//  weak points, deterrents) and export a real PDF via UIGraphicsPDFRenderer +
//  share sheet. iOS 14 safe (NSAttributedString drawing).
//

import SwiftUI
import UIKit

enum ReportSection: String, CaseIterable, Identifiable {
    case overview, risk, incidents, losses, perimeter, deterrents
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "Coop Overview"
        case .risk: return "Risk by Time"
        case .incidents: return "Attack Incidents"
        case .losses: return "Bird Losses"
        case .perimeter: return "Perimeter & Fixes"
        case .deterrents: return "Deterrents"
        }
    }
    var icon: String {
        switch self {
        case .overview: return "house.fill"
        case .risk: return "clock.fill"
        case .incidents: return "exclamationmark.octagon.fill"
        case .losses: return "bird.fill"
        case .perimeter: return "shield.lefthalf.filled"
        case .deterrents: return "eye.fill"
        }
    }
}

final class ReportsViewModel: ObservableObject {
    @Published var selected: Set<ReportSection> = Set(ReportSection.allCases)
    @Published var generated = false

    func toggle(_ s: ReportSection) {
        if selected.contains(s) { selected.remove(s) } else { selected.insert(s) }
    }

    func content(_ store: AppStore) -> [(ReportSection, [String])] {
        ReportSection.allCases.filter { selected.contains($0) }.map { ($0, lines(for: $0, store: store)) }
    }

    private func lines(for section: ReportSection, store: AppStore) -> [String] {
        switch section {
        case .overview:
            return [
                "Coop setup: \(store.coop.setup.displayName)",
                "Fence: \(Int(store.coop.fenceLengthMeters)) m · skirt: \(store.coop.hasDigSkirt ? "yes" : "no") · top net: \(store.coop.hasTopNet ? "yes" : "no")",
                "Birds: \(store.coop.birdCount) · lock-up \(Formatters.clock(hour: store.coop.lockUpHour, minute: store.coop.lockUpMinute))",
                "Active threats: \(store.activeThreats.map { $0.predator.displayName }.joined(separator: ", "))",
                "Current risk level: \(store.currentRiskLevel.displayName)"
            ]
        case .risk:
            let r = store.risk
            var l = [
                "Most dangerous hour: \(Formatters.hourLabel(r.mostDangerousHour)) (\(Int(r.score(at: r.mostDangerousHour)))/100)",
                "Dawn peak: \(Formatters.hourLabel(r.dawnPeakHour)) · Dusk peak: \(Formatters.hourLabel(r.duskPeakHour))"
            ]
            let top = r.hours.sorted { $0.score > $1.score }.prefix(5)
            l.append("Top hours: " + top.map { "\(Formatters.hourLabel($0.hour)) (\(Int($0.score)))" }.joined(separator: ", "))
            return l
        case .incidents:
            if store.incidents.isEmpty { return ["No attacks logged."] }
            return store.incidents.prefix(20).map {
                "\(Formatters.dateTime($0.date)) — \($0.predator.displayName), \($0.zone.displayName), \($0.entryMethod.displayName), \($0.birdsLost) lost"
            }
        case .losses:
            var l = ["Total birds lost: \(store.totalBirdsLost)", "Last 30 days: \(store.birdsLost(inLastDays: 30))"]
            l += store.lossesByCause().map { "\($0.cause.displayName): \($0.count)" }
            return l
        case .perimeter:
            var l = ["Perimeter protection: \(Int(store.perimeterScore))%",
                     "Open weak points: \(store.unresolvedWeakPoints.count) of \(store.weakPoints.count)"]
            l += store.weakPoints.map { "[\($0.isFixed ? "x" : " ")] \($0.type.displayName) — \($0.zone.displayName), \($0.priority.displayName)" }
            l.append("Fortifications done: \(store.completedFixCount)/\(store.fixes.count)")
            return l
        case .deterrents:
            if store.deterrents.isEmpty { return ["No deterrents in place."] }
            return store.deterrents.map { "\($0.type.displayName) at \($0.zone.displayName) — \($0.isActive ? "active" : "off")" }
        }
    }

    func makePDF(_ store: AppStore) -> URL? {
        let pageW: CGFloat = 595, pageH: CGFloat = 842, margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CoopWatch-Report.pdf")

        let titleAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 24), .foregroundColor: UIColor(hex: 0x0C111C)]
        let sectionAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor(hex: 0xDC2626)]
        let bodyAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor(hex: 0x222222)]
        let metaAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor(hex: 0x888888)]

        do {
            try renderer.writePDF(to: url) { ctx in
                var y: CGFloat = margin
                ctx.beginPage()
                func ensure(_ h: CGFloat) { if y + h > pageH - margin { ctx.beginPage(); y = margin } }
                func draw(_ text: String, _ attr: [NSAttributedString.Key: Any], _ height: CGFloat) {
                    ensure(height)
                    (text as NSString).draw(in: CGRect(x: margin, y: y, width: pageW - margin * 2, height: height), withAttributes: attr)
                    y += height
                }
                draw("Coop Watch — Defence Report", titleAttr, 34)
                draw("Generated \(Formatters.date(Date()))", metaAttr, 18)
                y += 6
                ctx.cgContext.setStrokeColor(UIColor(hex: 0xCCCCCC).cgColor)
                ctx.cgContext.move(to: CGPoint(x: margin, y: y)); ctx.cgContext.addLine(to: CGPoint(x: pageW - margin, y: y)); ctx.cgContext.strokePath()
                y += 14
                for (section, lines) in content(store) {
                    draw(section.title, sectionAttr, 24)
                    for line in lines { draw("•  " + line, bodyAttr, 18) }
                    y += 10
                }
                draw("Created with Coop Watch — lock the coop before dusk.", metaAttr, 16)
            }
            return url
        } catch { return nil }
    }
}

struct ReportsView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var vm = ReportsViewModel()
    @State private var shareURL: ShareURL?
    @State private var exportFailed = false

    struct ShareURL: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        ScreenScaffold("Reports", subtitle: "Share with the family or your vet", showFence: false) {
            HStack(spacing: 10) {
                ActionButton(title: "Generate", systemImage: "doc.badge.gearshape") { withAnimation { vm.generated = true } }
                ActionButton(title: "Export PDF", systemImage: "square.and.arrow.up", kind: .secondary) { exportPDF() }
            }

            CardView {
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: "Include sections", systemImage: "checklist")
                    ForEach(ReportSection.allCases) { section in
                        Toggle(isOn: Binding(get: { vm.selected.contains(section) },
                                             set: { _ in vm.toggle(section); vm.generated = false })) {
                            Label(section.title, systemImage: section.icon)
                                .font(Theme.body()).foregroundColor(Theme.textPrimary)
                        }.toggleStyle(SwitchToggleStyle(tint: Theme.alarm))
                    }
                }
            }

            if vm.generated { preview }
        }
        .sheet(item: $shareURL) { item in ShareSheet(items: [item.url]) }
        .alert(isPresented: $exportFailed) {
            Alert(title: Text("Export failed"), message: Text("Couldn't build the PDF. Try again."), dismissButton: .default(Text("OK")))
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Preview", subtitle: "Tap Export PDF to share", systemImage: "doc.text.magnifyingglass")
            ForEach(vm.content(store), id: \.0) { section, lines in
                CardView {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Image(systemName: section.icon).foregroundColor(Theme.dusk)
                            Text(section.title).font(Theme.heading(15)).foregroundColor(Theme.textPrimary) }
                        ForEach(lines, id: \.self) { line in
                            Text("• " + line).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func exportPDF() {
        if let url = vm.makePDF(store) { shareURL = ShareURL(url: url) } else { exportFailed = true }
    }
}
