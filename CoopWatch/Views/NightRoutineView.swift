//
//  NightRoutineView.swift  (Screen 07 — Night Routine)
//  CoopWatch
//
//  The evening lock-up checklist (all birds inside, door latched, light/trap
//  armed…). Resets automatically each new day. When every item is checked the
//  coop reads as Secured. iOS 14 safe.
//

import SwiftUI

struct NightRoutineView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAdd = false
    @State private var newTitle = ""

    var body: some View {
        ScreenScaffold("Night Routine", subtitle: "Lock-up by \(Formatters.clock(hour: store.coop.lockUpHour, minute: store.coop.lockUpMinute))",
                       showFence: false) {
            statusCard

            ForEach(store.nightTasks) { task in
                taskRow(task)
            }

            HStack(spacing: 10) {
                ActionButton(title: "Add step", systemImage: "plus", kind: .secondary) { newTitle = ""; showAdd = true }
                ActionButton(title: "Reset", systemImage: "arrow.counterclockwise", kind: .secondary) {
                    withAnimation { store.resetNightRoutine() }
                }
            }
        }
        .onAppear { store.resetNightRoutineIfNeeded() }
        .sheet(isPresented: $showAdd) { addSheet }
    }

    private var statusCard: some View {
        CardView(tint: store.isCoopSecured ? Theme.protectedC.opacity(0.5) : Theme.dusk.opacity(0.4)) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill((store.isCoopSecured ? Theme.protectedC : Theme.dusk).opacity(0.18))
                        .frame(width: 60, height: 60)
                    Image(systemName: store.isCoopSecured ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(store.isCoopSecured ? Theme.protectedC : Theme.dusk)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.isCoopSecured ? "Coop secured" : "Not locked up yet")
                        .font(Theme.heading(17)).foregroundColor(Theme.textPrimary)
                    Text("\(store.nightRoutineDone) of \(store.nightTasks.count) done tonight")
                        .font(Theme.caption()).foregroundColor(Theme.textSecondary)
                    ProgressBar(progress: store.nightRoutineProgress,
                                tint: store.isCoopSecured ? Theme.protectedC : Theme.dusk)
                        .frame(height: 7)
                }
            }
        }
    }

    private func taskRow(_ task: NightTask) -> some View {
        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { store.toggleNightTask(task) } }) {
            HStack(spacing: 12) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24)).foregroundColor(task.isDone ? Theme.protectedC : Theme.textSecondary)
                Image(systemName: task.icon).foregroundColor(Theme.dusk).frame(width: 24)
                Text(task.title).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                    .strikethrough(task.isDone, color: Theme.textSecondary)
                Spacer()
                Button(action: { store.deleteNightTask(task) }) {
                    Image(systemName: "trash").font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                }.buttonStyle(PlainButtonStyle())
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var addSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    CardView { LabeledField(label: "Checklist step", text: $newTitle, placeholder: "e.g. Lock the feed bin") }
                    ActionButton(title: "Add step", systemImage: "plus") {
                        let t = newTitle.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty else { return }
                        store.saveNightTask(NightTask(title: t, icon: "checkmark.circle"))
                        showAdd = false
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(newTitle.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
                .padding(Theme.Space.m)
            }
            .nightScreen(showFence: false)
            .navigationBarTitle("New Step", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { showAdd = false }.foregroundColor(Theme.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
