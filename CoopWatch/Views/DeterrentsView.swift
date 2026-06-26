//
//  DeterrentsView.swift  (Screen 08 — Deterrents)
//  CoopWatch
//
//  Repellents in place around the yard (motion lights, radio, predator eyes,
//  sprinklers…) with their zone and active state. Active deterrents lower the
//  modelled risk. iOS 14 safe.
//

import SwiftUI

struct DeterrentsView: View {
    @EnvironmentObject var store: AppStore
    @State private var sheet: DeterrentSheet?

    enum DeterrentSheet: Identifiable {
        case new, edit(Deterrent)
        var id: String { switch self { case .new: return "new"; case .edit(let d): return d.id.uuidString } }
    }

    var body: some View {
        ScreenScaffold("Deterrents", subtitle: "\(store.activeDeterrentCount) active of \(store.deterrents.count)",
                       showFence: false) {
            ActionButton(title: "Add deterrent", systemImage: "plus") { sheet = .new }

            CardView {
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill").foregroundColor(Theme.dusk)
                    Text("Move lights and decoys every week or two — predators learn static defences fast.")
                        .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                }
            }

            if store.deterrents.isEmpty {
                CardView { EmptyStateView(systemImage: "eye.slash", title: "No deterrents yet",
                                          message: "Add lights, radios or predator-eye decoys to push risk down.") }
            }

            ForEach(store.deterrents) { d in
                deterrentRow(d)
            }
        }
        .sheet(item: $sheet) { route in
            switch route {
            case .new: DeterrentEditor(existing: nil).environmentObject(store)
            case .edit(let d): DeterrentEditor(existing: d).environmentObject(store)
            }
        }
    }

    private func deterrentRow(_ d: Deterrent) -> some View {
        CardView(tint: d.isActive ? Theme.protectedC.opacity(0.4) : nil) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill((d.isActive ? Theme.protectedC : Theme.textSecondary).opacity(0.18)).frame(width: 40, height: 40)
                    Image(systemName: d.type.icon).foregroundColor(d.isActive ? Theme.protectedC : Theme.textSecondary)
                }
                Button(action: { sheet = .edit(d) }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.type.displayName).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                        Text(d.zone.displayName + (d.note.isEmpty ? "" : " · \(d.note)"))
                            .font(Theme.caption(11)).foregroundColor(Theme.textSecondary).lineLimit(1)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
                Toggle("", isOn: Binding(get: { d.isActive }, set: { _ in store.toggleDeterrent(d) }))
                    .labelsHidden().toggleStyle(SwitchToggleStyle(tint: Theme.protectedC))
            }
        }
    }
}

struct DeterrentEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) var presentationMode
    let existing: Deterrent?

    @State private var type: DeterrentType = .motionLight
    @State private var zone: Zone = .run
    @State private var isActive = true
    @State private var note = ""
    @State private var loaded = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            EnumMenu(title: "Type", selection: $type, options: DeterrentType.allCases) { $0.displayName }
                            EnumMenu(title: "Zone", selection: $zone, options: Zone.allCases) { $0.displayName }
                            Toggle(isOn: $isActive) {
                                Label("Currently active", systemImage: "power").font(Theme.body()).foregroundColor(Theme.textPrimary)
                            }.toggleStyle(SwitchToggleStyle(tint: Theme.protectedC))
                            LabeledField(label: "Note", text: $note, placeholder: "Where / details")
                        }
                    }
                    ActionButton(title: existing == nil ? "Add deterrent" : "Save changes", systemImage: "checkmark") { save() }
                    if existing != nil {
                        ActionButton(title: "Delete", systemImage: "trash", kind: .danger) {
                            if let e = existing { store.deleteDeterrent(e) }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .padding(Theme.Space.m)
            }
            .nightScreen(showFence: false)
            .navigationBarTitle(existing == nil ? "Add Deterrent" : "Edit Deterrent", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() }
                                    .foregroundColor(Theme.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            guard !loaded else { return }
            if let e = existing { type = e.type; zone = e.zone; isActive = e.isActive; note = e.note }
            loaded = true
        }
    }

    private func save() {
        var d = existing ?? Deterrent(type: type)
        d.type = type; d.zone = zone; d.isActive = isActive; d.note = note
        store.saveDeterrent(d)
        presentationMode.wrappedValue.dismiss()
    }
}
