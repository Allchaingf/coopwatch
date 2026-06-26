//
//  LossTrackerView.swift  (Screen 05 — Loss Tracker)
//  CoopWatch
//
//  Bird losses over time and by cause/predator. Predator losses are pulled from
//  the Attack Log automatically; non-predator losses (illness, escape) are added
//  here. Custom Path-based charts (no Swift Charts). iOS 14 safe.
//

import SwiftUI

struct LossTrackerView: View {
    @EnvironmentObject var store: AppStore
    @State private var sheet: LossSheet?

    enum LossSheet: Identifiable {
        case new, edit(BirdLoss)
        var id: String { switch self { case .new: return "new"; case .edit(let l): return l.id.uuidString } }
    }

    var body: some View {
        ScreenScaffold("Loss Tracker", subtitle: "\(store.totalBirdsLost) birds lost · \(store.birdsLost(inLastDays: 30)) in 30 days",
                       showFence: false) {
            ActionButton(title: "Record a loss", systemImage: "plus") { sheet = .new }

            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Weekly trend", subtitle: "Last 6 weeks", systemImage: "chart.line.downtrend.xyaxis")
                    LineChartView(values: store.weeklyLossSeries(weeks: 6),
                                  labels: weekLabels(), tint: Theme.attackC, height: 140)
                }
            }

            if !store.lossesByCause().isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "By cause", systemImage: "chart.pie.fill")
                        HStack(spacing: 18) {
                            DonutChartView(data: causeData(), size: 130, centerLabel: "birds")
                            ChartLegend(items: causeData())
                        }
                    }
                }
            }

            if !store.lossesByPredator().isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "By predator", systemImage: "pawprint.fill")
                        BarChartView(data: predatorData(), height: 130)
                    }
                }
            }

            SectionHeader(title: "Records", systemImage: "list.bullet")
            if store.combinedLosses.isEmpty {
                CardView { EmptyStateView(systemImage: "bird", title: "No losses recorded",
                                          message: "That's the goal. Record any losses to spot patterns.") }
            }
            ForEach(store.combinedLosses) { loss in
                lossRow(loss)
            }
        }
        .sheet(item: $sheet) { route in
            switch route {
            case .new: LossEditor(existing: nil).environmentObject(store)
            case .edit(let l): LossEditor(existing: l).environmentObject(store)
            }
        }
    }

    private func weekLabels() -> [String] {
        let cal = Calendar.current
        return (0..<6).reversed().map { w in
            let d = cal.date(byAdding: .day, value: -7 * w, to: Date()) ?? Date()
            return Formatters.dayMonth(d)
        }
    }
    private func causeData() -> [ChartDatum] {
        store.lossesByCause().map { ChartDatum(label: $0.cause.displayName, value: Double($0.count), color: $0.cause.color) }
    }
    private func predatorData() -> [ChartDatum] {
        store.lossesByPredator().map { ChartDatum(label: $0.predator.displayName, value: Double($0.count), color: $0.predator.tint) }
    }

    @ViewBuilder
    private func lossRow(_ loss: BirdLoss) -> some View {
        // Predator losses come from incidents (read-only here); standalone are editable.
        let isStandalone = store.losses.contains { $0.id == loss.id }
        let content = CardView {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(loss.cause.color.opacity(0.2)).frame(width: 38, height: 38)
                    Image(systemName: loss.cause.icon).foregroundColor(loss.cause.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(loss.count) bird\(loss.count == 1 ? "" : "s") · \(loss.cause.displayName)")
                        .font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                    Text(Formatters.date(loss.date) + (loss.note.isEmpty ? "" : " · \(loss.note)"))
                        .font(Theme.caption(11)).foregroundColor(Theme.textSecondary).lineLimit(1)
                }
                Spacer()
                if !isStandalone {
                    Image(systemName: "exclamationmark.octagon.fill").foregroundColor(Theme.attackC.opacity(0.7))
                } else {
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                }
            }
        }
        if isStandalone {
            Button(action: { sheet = .edit(loss) }) { content }.buttonStyle(PlainButtonStyle())
        } else {
            content
        }
    }
}

// MARK: - Loss editor (standalone losses)

struct LossEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) var presentationMode
    let existing: BirdLoss?

    @State private var date = Date()
    @State private var count = 1
    @State private var cause: LossCause = .illness
    @State private var predator: PredatorType? = nil
    @State private var note = ""
    @State private var loaded = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            VStack(alignment: .leading, spacing: 5) {
                                FieldLabel(text: "When")
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden().accentColor(Theme.alarm)
                            }
                            LabeledNumberField(label: "Birds lost", value: $count, suffix: "birds")
                            EnumMenu(title: "Cause", selection: $cause, options: LossCause.allCases) { $0.displayName }
                            if cause == .predator {
                                EnumMenu(title: "Predator", selection: Binding(
                                    get: { predator ?? .fox }, set: { predator = $0 }),
                                         options: PredatorType.allCases) { $0.displayName }
                            }
                            LabeledField(label: "Note", text: $note, placeholder: "Optional detail")
                        }
                    }
                    ActionButton(title: existing == nil ? "Save loss" : "Save changes", systemImage: "checkmark") { save() }
                    if existing != nil {
                        ActionButton(title: "Delete", systemImage: "trash", kind: .danger) {
                            if let e = existing { store.deleteLoss(e) }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .padding(Theme.Space.m)
            }
            .nightScreen(showFence: false)
            .navigationBarTitle(existing == nil ? "Record Loss" : "Edit Loss", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() }
                                    .foregroundColor(Theme.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            guard !loaded else { return }
            if let e = existing { date = e.date; count = e.count; cause = e.cause; predator = e.predator; note = e.note }
            loaded = true
        }
    }

    private func save() {
        var l = existing ?? BirdLoss()
        l.date = date; l.count = max(1, count); l.cause = cause
        l.predator = cause == .predator ? predator : nil; l.note = note
        store.saveLoss(l)
        presentationMode.wrappedValue.dismiss()
    }
}
