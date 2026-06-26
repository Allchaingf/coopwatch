//
//  AddWeakPointView.swift  (Screen 02 — Add / Inspect Weak Point)
//  CoopWatch
//
//  Shared editor used for both adding a new weak point and inspecting/editing
//  an existing one. Pick type / zone / priority / status, drag the pin to place
//  it on the perimeter, attach a photo and write a remediation note. Edit mode
//  also offers Fix and Delete. iOS 14 safe.
//

import SwiftUI

private enum PickerKind: Int, Identifiable { case camera, library; var id: Int { rawValue } }

struct WeakPointEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) var presentationMode

    let existing: WeakPoint?

    @State private var type: WeakPointType = .gap
    @State private var zone: Zone = .north
    @State private var priority: Priority = .medium
    @State private var status: ProtectionStatus = .exposed
    @State private var note = ""
    @State private var remediation = ""
    @State private var imageFileName: String?
    @State private var mapX: Double = 0.5
    @State private var mapY: Double = 0.5
    @State private var loaded = false

    @State private var showSource = false
    @State private var picker: PickerKind?

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    miniMap
                    typeGrid

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            EnumMenu(title: "Zone", selection: $zone, options: Zone.allCases) { $0.displayName }
                                .onChange(of: zone) { newZone in
                                    // snap to the zone's anchor when the zone changes
                                    mapX = Double(newZone.anchor.x); mapY = Double(newZone.anchor.y)
                                }
                            EnumMenu(title: "Priority", selection: $priority, options: Priority.allCases) { $0.displayName }
                            EnumMenu(title: "Status", selection: $status, options: ProtectionStatus.allCases) { $0.displayName }
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            LabeledField(label: "Note", text: $note, placeholder: "What's wrong here?")
                            LabeledField(label: "Remediation", text: $remediation,
                                         placeholder: type.fixHint)
                        }
                    }

                    photoCard

                    ActionButton(title: isEditing ? "Save changes" : "Add weak point",
                                 systemImage: "checkmark") { save() }
                    if isEditing {
                        HStack(spacing: 10) {
                            if status != .protectedNow {
                                ActionButton(title: "Mark protected", systemImage: "checkmark.shield.fill", kind: .safe) {
                                    status = .protectedNow; save()
                                }
                            }
                            ActionButton(title: "Delete", systemImage: "trash", kind: .danger) {
                                if let e = existing { store.deleteWeakPoint(e) }
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                }
                .padding(Theme.Space.m)
            }
            .nightScreen(showFence: false)
            .navigationBarTitle(isEditing ? "Inspect Point" : "Add Weak Point", displayMode: .inline)
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
            Group {
                if kind == .camera { CameraPicker { handle($0) } }
                else { PhotoLibraryPicker { handle($0) } }
            }
        }
        .onAppear {
            guard !loaded else { return }
            if let e = existing {
                type = e.type; zone = e.zone; priority = e.priority; status = e.status
                note = e.note; remediation = e.remediation; imageFileName = e.imageFileName
                mapX = e.mapX; mapY = e.mapY
            } else {
                mapX = Double(zone.anchor.x); mapY = Double(zone.anchor.y)
            }
            loaded = true
        }
    }

    // MARK: Mini map (drag to place)

    private var miniMap: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: "Drag the pin to its spot")
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceAlt)
                    RoundedRectangle(cornerRadius: 9).stroke(Theme.moon, lineWidth: 2).padding(12)
                    CoopShape().stroke(Theme.dusk, lineWidth: 1.6)
                        .frame(width: w * 0.22, height: h * 0.2).position(x: w * 0.30, y: h * 0.34)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 30)).foregroundColor(status.color)
                        .shadow(color: status.color.opacity(0.8), radius: 5)
                        .position(x: CGFloat(mapX) * w, y: CGFloat(mapY) * h)
                        .gesture(DragGesture().onChanged { v in
                            mapX = Double(min(max(v.location.x / w, 0.04), 0.96))
                            mapY = Double(min(max(v.location.y / h, 0.04), 0.96))
                        })
                }
            }
            .frame(height: 180)
        }
    }

    private var typeGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: "Type of weakness")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(WeakPointType.allCases) { t in
                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { type = t } }) {
                        HStack(spacing: 8) {
                            Image(systemName: t.icon).foregroundColor(type == t ? Theme.textOnAccent : Theme.dusk)
                            Text(t.displayName).font(Theme.caption(12))
                                .foregroundColor(type == t ? Theme.textOnAccent : Theme.textPrimary)
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.s)
                            .fill(type == t ? Theme.dusk : Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
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
                    ActionButton(title: imageFileName == nil ? "Attach Photo" : "Replace",
                                 systemImage: "camera.fill", kind: .secondary) { showSource = true }
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
        var wp = existing ?? WeakPoint(type: type, zone: zone)
        wp.type = type; wp.zone = zone; wp.priority = priority; wp.status = status
        wp.note = note; wp.remediation = remediation; wp.imageFileName = imageFileName
        wp.mapX = mapX; wp.mapY = mapY
        if status == .protectedNow && wp.resolvedAt == nil { wp.resolvedAt = Date() }
        if status != .protectedNow { wp.resolvedAt = nil }
        store.saveWeakPoint(wp)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Reusable enum menu picker

struct EnumMenu<T: Identifiable & Equatable>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            FieldLabel(text: title)
            Menu {
                ForEach(options) { opt in
                    Button(action: { selection = opt }) {
                        HStack {
                            Text(label(opt))
                            if opt == selection { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(label(selection)).font(Theme.body()).foregroundColor(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
            }
        }
    }
}
