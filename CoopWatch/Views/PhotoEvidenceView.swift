//
//  PhotoEvidenceView.swift  (Screen 10 — Photo Evidence)
//  CoopWatch
//
//  A gallery of damage/track photos. Standalone evidence is added here and can
//  be marked up (caption, tag, a draggable pin on the damage). Photos attached
//  to incidents and sightings are surfaced read-only so everything's in one
//  place. iOS 14 safe.
//

import SwiftUI

struct PhotoEvidenceView: View {
    @EnvironmentObject var store: AppStore
    @State private var showSource = false
    @State private var sheet: EvidenceSheet?

    enum EvidenceSheet: Identifiable {
        case camera, library, detail(PhotoEvidence)
        var id: String {
            switch self { case .camera: return "cam"; case .library: return "lib"; case .detail(let p): return p.id.uuidString }
        }
    }

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    // Read-only thumbnails pulled from other records.
    private var linkedImages: [(name: String, label: String)] {
        var out: [(String, String)] = []
        for i in store.incidents where i.imageFileName != nil {
            out.append((i.imageFileName!, "\(i.predator.displayName) attack"))
        }
        for s in store.sightings where s.imageFileName != nil {
            out.append((s.imageFileName!, s.evidence.displayName))
        }
        for w in store.weakPoints where w.imageFileName != nil {
            out.append((w.imageFileName!, w.type.displayName))
        }
        return out
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Photo Evidence").font(Theme.title(27)).foregroundColor(Theme.textPrimary)
                        Text("\(store.photos.count) marked · \(linkedImages.count) linked")
                            .font(Theme.caption()).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    MoonView(size: 40)
                }
                .padding(.top, 4)

                ActionButton(title: "Add evidence photo", systemImage: "camera.fill") { showSource = true }

                if store.photos.isEmpty && linkedImages.isEmpty {
                    CardView { EmptyStateView(systemImage: "photo.on.rectangle.angled", title: "No photos yet",
                                              message: "Capture damage or tracks and pin the exact spot.") }
                }

                if !store.photos.isEmpty {
                    SectionHeader(title: "Marked evidence", systemImage: "mappin.and.ellipse")
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(store.photos.sorted { $0.createdAt > $1.createdAt }) { photo in
                            Button(action: { sheet = .detail(photo) }) { tile(photo) }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                if !linkedImages.isEmpty {
                    SectionHeader(title: "From logs", systemImage: "link")
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(Array(linkedImages.enumerated()), id: \.offset) { _, item in
                            linkedTile(item.name, item.label)
                        }
                    }
                }
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 110)
        }
        .nightScreen(showFence: false)
        .navigationBarHidden(true)
        .actionSheet(isPresented: $showSource) {
            ActionSheet(title: Text("Add an evidence photo"), buttons: [
                .default(Text("Take Photo")) { sheet = .camera },
                .default(Text("Choose from Library")) { sheet = .library },
                .cancel()
            ])
        }
        .sheet(item: $sheet) { route in
            switch route {
            case .camera: CameraPicker { handle($0) }
            case .library: PhotoLibraryPicker { handle($0) }
            case .detail(let p): PhotoEvidenceDetail(photoID: p.id).environmentObject(store)
            }
        }
    }

    private func tile(_ photo: PhotoEvidence) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if let img = PhotoStore.shared.loadImage(named: photo.imageFileName) {
                    Image(uiImage: img).resizable().aspectRatio(1, contentMode: .fill)
                        .frame(height: 150).clipped().clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s))
                        .overlay(markerOverlay(photo))
                } else {
                    RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt).frame(height: 150)
                        .overlay(Image(systemName: "photo").foregroundColor(Theme.textSecondary))
                }
                if !photo.tag.isEmpty {
                    TagChip(text: photo.tag, color: Theme.alarm, filled: true).padding(6)
                }
            }
            Text(photo.caption.isEmpty ? "Untitled" : photo.caption)
                .font(Theme.caption()).foregroundColor(Theme.textPrimary).lineLimit(1)
        }
    }

    private func markerOverlay(_ photo: PhotoEvidence) -> some View {
        GeometryReader { geo in
            Image(systemName: "scope").font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.alarm).shadow(color: .black, radius: 2)
                .position(x: geo.size.width * CGFloat(photo.markerX), y: geo.size.height * CGFloat(photo.markerY))
        }
    }

    private func linkedTile(_ name: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let img = PhotoStore.shared.loadImage(named: name) {
                Image(uiImage: img).resizable().aspectRatio(1, contentMode: .fill)
                    .frame(height: 150).clipped().clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s))
            } else {
                RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt).frame(height: 150)
            }
            Text(label).font(Theme.caption()).foregroundColor(Theme.textSecondary).lineLimit(1)
        }
    }

    private func handle(_ image: UIImage) {
        guard let name = PhotoStore.shared.save(image) else { return }
        let photo = PhotoEvidence(caption: "", tag: "", imageFileName: name, markerX: 0.5, markerY: 0.5)
        store.savePhoto(photo)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { sheet = .detail(photo) }
    }
}

// MARK: - Markup detail

struct PhotoEvidenceDetail: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) var presentationMode
    let photoID: UUID

    @State private var caption = ""
    @State private var tag = ""
    @State private var markerX: Double = 0.5
    @State private var markerY: Double = 0.5
    @State private var loaded = false

    private var photo: PhotoEvidence? { store.photos.first { $0.id == photoID } }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Text("Drag the marker onto the damage / tracks")
                        .font(Theme.caption()).foregroundColor(Theme.textSecondary)
                    GeometryReader { geo in
                        ZStack {
                            if let img = PhotoStore.shared.loadImage(named: photo?.imageFileName) {
                                Image(uiImage: img).resizable().aspectRatio(contentMode: .fit).frame(width: geo.size.width)
                            } else {
                                RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt)
                            }
                            Image(systemName: "scope").font(.system(size: 34, weight: .bold))
                                .foregroundColor(Theme.alarm).shadow(color: .black, radius: 3)
                                .position(x: geo.size.width * CGFloat(markerX), y: geo.size.height * CGFloat(markerY))
                                .gesture(DragGesture().onChanged { v in
                                    markerX = Double(min(max(v.location.x / geo.size.width, 0), 1))
                                    markerY = Double(min(max(v.location.y / geo.size.height, 0), 1))
                                })
                        }
                    }
                    .frame(height: 300)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))

                    LabeledField(label: "Caption", text: $caption, placeholder: "What / where")
                    LabeledField(label: "Tag", text: $tag, placeholder: "e.g. dig, claw, feathers")

                    HStack(spacing: 10) {
                        ActionButton(title: "Save", systemImage: "checkmark") { save() }
                        ActionButton(title: "Delete", systemImage: "trash", kind: .danger) {
                            if let p = photo { store.deletePhoto(p) }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .padding(Theme.Space.m)
            }
            .nightScreen(showFence: false)
            .navigationBarTitle("Mark Evidence", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() }
                                    .foregroundColor(Theme.textSecondary))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            guard !loaded, let p = photo else { return }
            caption = p.caption; tag = p.tag; markerX = p.markerX; markerY = p.markerY; loaded = true
        }
    }

    private func save() {
        guard var p = photo else { presentationMode.wrappedValue.dismiss(); return }
        p.caption = caption; p.tag = tag; p.markerX = markerX; p.markerY = markerY
        store.savePhoto(p)
        presentationMode.wrappedValue.dismiss()
    }
}
