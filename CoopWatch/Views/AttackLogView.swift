//
//  AttackLogView.swift  (Screen 04 — Attack Log)
//  CoopWatch
//
//  Records each predator incident: which predator, when, the entry zone & how
//  it got in, and how many birds were lost. Every saved incident feeds the Risk
//  Clock (its hour) and the Loss Tracker. iOS 14 safe.
//

import SwiftUI

struct AttackLogView: View {
    @EnvironmentObject var store: AppStore
    @State private var sheet: IncidentSheet?

    enum IncidentSheet: Identifiable {
        case new, edit(AttackIncident)
        var id: String { switch self { case .new: return "new"; case .edit(let i): return i.id.uuidString } }
    }

    var body: some View {
        ScreenScaffold("Attack Log", subtitle: "\(store.incidents.count) incidents · \(store.totalBirdsLost) birds lost",
                       showFence: false) {
            ActionButton(title: "Log an attack", systemImage: "plus") { sheet = .new }

            if store.incidents.isEmpty {
                CardView { EmptyStateView(systemImage: "pawprint.slash", title: "No attacks logged",
                                          message: "Log incidents so the risk clock learns your yard's danger hours.") }
            }

            ForEach(store.incidents) { inc in
                Button(action: { sheet = .edit(inc) }) { row(inc) }.buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(item: $sheet) { route in
            switch route {
            case .new: IncidentEditor(existing: nil).environmentObject(store)
            case .edit(let inc): IncidentEditor(existing: inc).environmentObject(store)
            }
        }
    }

    private func row(_ inc: AttackIncident) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        Circle().fill(inc.predator.tint.opacity(0.2)).frame(width: 40, height: 40)
                        Image(systemName: inc.predator.icon).foregroundColor(inc.predator.tint)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(inc.predator.displayName).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                        Text(Formatters.dateTime(inc.date)).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    if inc.birdsLost > 0 {
                        TagChip(text: "-\(inc.birdsLost) bird\(inc.birdsLost == 1 ? "" : "s")", color: Theme.attackC, filled: true)
                    }
                }
                HStack(spacing: 10) {
                    Label(inc.zone.displayName, systemImage: "mappin").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    Label(inc.entryMethod.displayName, systemImage: inc.entryMethod.icon).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(Formatters.hourLabel(inc.hour)).font(Theme.caption(11)).foregroundColor(Theme.dusk)
                }
                if !inc.note.isEmpty {
                    Text(inc.note).font(Theme.caption()).foregroundColor(Theme.textPrimary).lineLimit(2)
                }
                if let img = PhotoStore.shared.loadImage(named: inc.imageFileName) {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                        .frame(height: 120).clipped().clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s))
                }
            }
        }
    }
}

// MARK: - Incident editor

private enum PickerKind: Int, Identifiable { case camera, library; var id: Int { rawValue } }

struct IncidentEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) var presentationMode
    let existing: AttackIncident?

    @State private var predator: PredatorType = .fox
    @State private var date = Date()
    @State private var zone: Zone = .run
    @State private var method: EntryMethod = .unknown
    @State private var birdsLost = 0
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
                            EnumMenu(title: "Predator", selection: $predator, options: PredatorType.allCases) { $0.displayName }
                            VStack(alignment: .leading, spacing: 5) {
                                FieldLabel(text: "When")
                                DatePicker("", selection: $date).labelsHidden().accentColor(Theme.alarm)
                            }
                            EnumMenu(title: "Entry zone", selection: $zone, options: Zone.allCases) { $0.displayName }
                            EnumMenu(title: "How it got in", selection: $method, options: EntryMethod.allCases) { $0.displayName }
                            LabeledNumberField(label: "Birds lost", value: $birdsLost, suffix: "birds")
                        }
                    }
                    CardView {
                        LabeledField(label: "Note", text: $note, placeholder: "What happened?")
                    }
                    photoCard
                    ActionButton(title: existing == nil ? "Save incident" : "Save changes", systemImage: "checkmark") { save() }
                    if existing != nil {
                        ActionButton(title: "Delete", systemImage: "trash", kind: .danger) {
                            if let e = existing { store.deleteIncident(e) }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .padding(Theme.Space.m)
            }
            .nightScreen(showFence: false)
            .navigationBarTitle(existing == nil ? "Log Attack" : "Edit Attack", displayMode: .inline)
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
                predator = e.predator; date = e.date; zone = e.zone; method = e.entryMethod
                birdsLost = e.birdsLost; note = e.note; imageFileName = e.imageFileName
            }
            loaded = true
        }
    }

    private var photoCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Photo evidence", systemImage: "camera.fill")
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

    private func handle(_ image: UIImage) {
        if let name = PhotoStore.shared.save(image) { imageFileName = name }
    }

    private func save() {
        var inc = existing ?? AttackIncident()
        inc.predator = predator; inc.date = date; inc.zone = zone; inc.entryMethod = method
        inc.birdsLost = birdsLost; inc.note = note; inc.imageFileName = imageFileName
        store.saveIncident(inc)
        presentationMode.wrappedValue.dismiss()
    }
}
