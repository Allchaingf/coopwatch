//
//  TrapSightingView.swift  (Screen 09 — Trap & Sighting)
//  CoopWatch
//
//  Logs predator evidence near the coop — tracks, droppings, paw prints, sounds,
//  kill sites — with a guessed predator. Sightings feed the risk clock at half
//  the weight of a confirmed attack. iOS 14 safe.
//

import SwiftUI

struct TrapSightingView: View {
    @EnvironmentObject var store: AppStore
    @State private var sheet: SightingSheet?

    enum SightingSheet: Identifiable {
        case new, edit(Sighting)
        var id: String { switch self { case .new: return "new"; case .edit(let s): return s.id.uuidString } }
    }

    var body: some View {
        ScreenScaffold("Trap & Sightings", subtitle: "\(store.sightings.count) signs logged", showFence: false) {
            ActionButton(title: "Log a sighting", systemImage: "plus") { sheet = .new }

            if store.sightings.isEmpty {
                CardView { EmptyStateView(systemImage: "pawprint", title: "No signs yet",
                                          message: "Record tracks, droppings or sounds to catch threats before they strike.") }
            }
            ForEach(store.sightings) { s in
                Button(action: { sheet = .edit(s) }) { row(s) }.buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(item: $sheet) { route in
            switch route {
            case .new: SightingEditor(existing: nil).environmentObject(store)
            case .edit(let s): SightingEditor(existing: s).environmentObject(store)
            }
        }
    }

    private func row(_ s: Sighting) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        Circle().fill(Theme.dusk.opacity(0.18)).frame(width: 40, height: 40)
                        Image(systemName: s.evidence.icon).foregroundColor(Theme.dusk)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.evidence.displayName).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                        Text("\(s.zone.displayName) · \(Formatters.relativeDays(to: s.date))")
                            .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    if let g = s.predatorGuess { TagChip(text: g.displayName, color: g.tint) }
                }
                if !s.nearbyActivity.isEmpty {
                    Text(s.nearbyActivity).font(Theme.caption()).foregroundColor(Theme.textPrimary).lineLimit(2)
                }
                if let img = PhotoStore.shared.loadImage(named: s.imageFileName) {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                        .frame(height: 120).clipped().clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s))
                }
            }
        }
    }
}

private enum PickerKind: Int, Identifiable { case camera, library; var id: Int { rawValue } }

struct SightingEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) var presentationMode
    let existing: Sighting?

    @State private var evidence: SightingEvidence = .tracks
    @State private var date = Date()
    @State private var zone: Zone = .north
    @State private var hasGuess = false
    @State private var guess: PredatorType = .fox
    @State private var nearby = ""
    @State private var note = ""
    @State private var imageFileName: String?
    @State private var loaded = false
    @State private var showSource = false
    @State private var picker: PickerKind?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            EnumMenu(title: "Evidence", selection: $evidence, options: SightingEvidence.allCases) { $0.displayName }
                            VStack(alignment: .leading, spacing: 5) {
                                FieldLabel(text: "When")
                                DatePicker("", selection: $date).labelsHidden().accentColor(Theme.alarm)
                            }
                            EnumMenu(title: "Zone", selection: $zone, options: Zone.allCases) { $0.displayName }
                            Toggle(isOn: $hasGuess) {
                                Label("Guess the predator", systemImage: "pawprint.fill").font(Theme.body()).foregroundColor(Theme.textPrimary)
                            }.toggleStyle(SwitchToggleStyle(tint: Theme.dusk))
                            if hasGuess {
                                EnumMenu(title: "Predator", selection: $guess, options: PredatorType.allCases) { $0.displayName }
                            }
                            LabeledField(label: "Nearby activity", text: $nearby, placeholder: "Direction, freshness…")
                            LabeledField(label: "Note", text: $note, placeholder: "Optional")
                        }
                    }
                    photoCard
                    ActionButton(title: existing == nil ? "Save sighting" : "Save changes", systemImage: "checkmark") { save() }
                    if existing != nil {
                        ActionButton(title: "Delete", systemImage: "trash", kind: .danger) {
                            if let e = existing { store.deleteSighting(e) }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .padding(Theme.Space.m)
            }
            .nightScreen(showFence: false)
            .navigationBarTitle(existing == nil ? "Log Sighting" : "Edit Sighting", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() }
                                    .foregroundColor(Theme.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .actionSheet(isPresented: $showSource) {
            ActionSheet(title: Text("Attach a photo"), buttons: [
                .default(Text("Take Photo")) { picker = .camera },
                .default(Text("Choose from Library")) { picker = .library },
                .cancel()
            ])
        }
        .sheet(item: $picker) { kind in
            Group { if kind == .camera { CameraPicker { handle($0) } } else { PhotoLibraryPicker { handle($0) } } }
        }
        .onAppear {
            guard !loaded else { return }
            if let e = existing {
                evidence = e.evidence; date = e.date; zone = e.zone
                hasGuess = e.predatorGuess != nil; guess = e.predatorGuess ?? .fox
                nearby = e.nearbyActivity; note = e.note; imageFileName = e.imageFileName
            }
            loaded = true
        }
    }

    private var photoCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Photo", systemImage: "camera.fill")
                if let img = PhotoStore.shared.loadImage(named: imageFileName) {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                        .frame(height: 150).clipped().clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s))
                }
                HStack(spacing: 10) {
                    ActionButton(title: imageFileName == nil ? "Attach" : "Replace", systemImage: "camera.fill", kind: .secondary) { showSource = true }
                    if imageFileName != nil {
                        ActionButton(title: "Remove", systemImage: "trash", kind: .danger) {
                            PhotoStore.shared.delete(named: imageFileName); imageFileName = nil
                        }
                    }
                }
            }
        }
    }

    private func handle(_ image: UIImage) { if let name = PhotoStore.shared.save(image) { imageFileName = name } }

    private func save() {
        var s = existing ?? Sighting()
        s.evidence = evidence; s.date = date; s.zone = zone
        s.predatorGuess = hasGuess ? guess : nil
        s.nearbyActivity = nearby; s.note = note; s.imageFileName = imageFileName
        store.saveSighting(s)
        presentationMode.wrappedValue.dismiss()
    }
}
