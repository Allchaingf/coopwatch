//
//  FixChecklistView.swift  (Screen 06 — Fix Checklist)
//  CoopWatch
//
//  The fortification checklist (dig apron, top net, locks, light/sensor, mesh
//  upgrades…). Completed fortifications lower the modelled risk. Add custom
//  items, toggle done, delete. iOS 14 safe.
//

import SwiftUI

struct FixChecklistView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAdd = false
    @State private var newTitle = ""
    @State private var newDetail = ""

    var body: some View {
        ScreenScaffold("Fix Checklist", subtitle: "\(store.completedFixCount)/\(store.fixes.count) fortifications done",
                       showFence: false) {
            CardView {
                HStack(spacing: 16) {
                    ProgressRing(progress: progress, size: 60, lineWidth: 7, tint: Theme.protectedC)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hardening progress").font(Theme.caption()).foregroundColor(Theme.textSecondary)
                        Text(progress >= 100 ? "Fully fortified" : "Keep going")
                            .font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                        Text("Each fix lowers your risk clock").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
            }

            ActionButton(title: "Add fortification", systemImage: "plus", kind: .secondary) {
                newTitle = ""; newDetail = ""; showAdd = true
            }

            ForEach(store.fixes) { fix in
                fixRow(fix)
            }
        }
        .sheet(isPresented: $showAdd) { addSheet }
    }

    private var progress: Double {
        guard !store.fixes.isEmpty else { return 0 }
        return Double(store.completedFixCount) / Double(store.fixes.count) * 100
    }

    private func fixRow(_ fix: FixItem) -> some View {
        CardView(tint: fix.isDone ? Theme.protectedC.opacity(0.45) : nil) {
            HStack(spacing: 12) {
                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { store.toggleFix(fix) } }) {
                    Image(systemName: fix.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24)).foregroundColor(fix.isDone ? Theme.protectedC : Theme.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())

                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Theme.dusk.opacity(0.16)).frame(width: 36, height: 36)
                    Image(systemName: fix.icon).foregroundColor(Theme.dusk).font(.system(size: 15))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(fix.title).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                        .strikethrough(fix.isDone, color: Theme.textSecondary)
                    if !fix.detail.isEmpty {
                        Text(fix.detail).font(Theme.caption(11)).foregroundColor(Theme.textSecondary).lineLimit(2)
                    }
                    if let done = fix.completedAt {
                        Text("Done \(Formatters.relativeDays(to: done))").font(Theme.caption(10)).foregroundColor(Theme.protectedC)
                    }
                }
                Spacer()
                Button(action: { store.deleteFix(fix) }) {
                    Image(systemName: "trash").font(.system(size: 14)).foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var addSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            LabeledField(label: "Fortification", text: $newTitle, placeholder: "e.g. Concrete the gate base")
                            LabeledField(label: "Detail", text: $newDetail, placeholder: "Optional")
                        }
                    }
                    ActionButton(title: "Add to checklist", systemImage: "plus") {
                        let t = newTitle.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty else { return }
                        store.saveFix(FixItem(title: t, detail: newDetail, icon: "wrench.and.screwdriver.fill"))
                        showAdd = false
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(newTitle.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
                .padding(Theme.Space.m)
            }
            .nightScreen(showFence: false)
            .navigationBarTitle("New Fortification", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { showAdd = false }.foregroundColor(Theme.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
