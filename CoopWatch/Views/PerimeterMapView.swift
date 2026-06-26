//
//  PerimeterMapView.swift  (Screen 01 — flagship)
//  CoopWatch
//
//  A live schematic of the perimeter: fence rectangle, coop, gate, optional dig
//  skirt and top net, with weak points plotted as status-coloured markers.
//  Buttons: Add Point / Fix / Inspect. Tapping a marker (or list row) selects
//  it. Also links the rest of the defences. iOS 14 safe.
//

import SwiftUI

struct PerimeterMapView: View {
    @EnvironmentObject var store: AppStore

    @State private var selectedID: UUID?
    @State private var sheet: PointSheet?
    @State private var alert: MapAlert?

    enum PointSheet: Identifiable {
        case add, edit(WeakPoint)
        var id: String { switch self { case .add: return "add"; case .edit(let w): return w.id.uuidString } }
    }
    enum MapAlert: Identifiable {
        case selectFirst, alreadyFixed, fixed(String)
        var id: String {
            switch self { case .selectFirst: return "s"; case .alreadyFixed: return "a"; case .fixed(let z): return "f\(z)" }
        }
    }

    private var selected: WeakPoint? { store.weakPoints.first { $0.id == selectedID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                header
                mapCard
                buttonRow
                if let s = selected { selectionCard(s) }
                legend
                pointList
                defencesSection
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 110)
        }
        .nightScreen(showFence: false)
        .navigationBarHidden(true)
        .sheet(item: $sheet) { route in
            switch route {
            case .add: WeakPointEditor(existing: nil).environmentObject(store)
            case .edit(let wp): WeakPointEditor(existing: wp).environmentObject(store)
            }
        }
        .alert(item: $alert) { a in
            switch a {
            case .selectFirst:
                return Alert(title: Text("Pick a point"),
                             message: Text("Tap a weak point on the map or in the list first."),
                             dismissButton: .default(Text("OK")))
            case .alreadyFixed:
                return Alert(title: Text("Already protected"),
                             message: Text("This point is already marked as fixed."),
                             dismissButton: .default(Text("OK")))
            case .fixed(let zone):
                return Alert(title: Text("Marked protected"),
                             message: Text("The \(zone) weak point is now secured. Risk recalculated."),
                             dismissButton: .default(Text("Nice")))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Perimeter Map").font(Theme.title(27)).foregroundColor(Theme.textPrimary)
                Text("\(store.unresolvedWeakPoints.count) open · \(store.weakPoints.count) total")
                    .font(Theme.caption()).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            RiskBadge(level: store.currentRiskLevel, compact: true)
        }
        .padding(.top, 4)
    }

    // MARK: Map

    private var mapCard: some View {
        CardView(padding: 0) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceAlt)

                    if store.coop.hasDigSkirt {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                            .foregroundColor(Theme.protectedC.opacity(0.7))
                            .padding(7)
                    }
                    // fence
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(Theme.moon, lineWidth: 2)
                        .padding(15)
                    // top net
                    if store.coop.hasTopNet {
                        topNet.padding(15)
                    }
                    // compass labels
                    Text("N").font(Theme.caption(10)).foregroundColor(Theme.textSecondary).position(x: w/2, y: 24)
                    Text("S").font(Theme.caption(10)).foregroundColor(Theme.textSecondary).position(x: w/2, y: h-22)
                    Text("W").font(Theme.caption(10)).foregroundColor(Theme.textSecondary).position(x: 26, y: h/2)
                    Text("E").font(Theme.caption(10)).foregroundColor(Theme.textSecondary).position(x: w-24, y: h/2)
                    // gate
                    VStack(spacing: 1) {
                        Image(systemName: "door.left.hand.closed").font(.system(size: 14))
                            .foregroundColor(Theme.dusk)
                        Text("Gate").font(Theme.caption(8)).foregroundColor(Theme.textSecondary)
                    }
                    .position(x: w * 0.5, y: h - 16)
                    // coop
                    CoopShape()
                        .stroke(Theme.dusk, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                        .frame(width: w * 0.26, height: h * 0.22)
                        .position(x: w * 0.32, y: h * 0.34)
                    Text("Coop").font(Theme.caption(8)).foregroundColor(Theme.textSecondary)
                        .position(x: w * 0.32, y: h * 0.50)

                    // weak point markers
                    ForEach(store.weakPoints) { wp in
                        marker(wp, in: CGSize(width: w, height: h))
                    }
                }
            }
            .frame(height: 320)
        }
    }

    private var topNet: some View {
        GeometryReader { g in
            Path { p in
                let step: CGFloat = 16
                var x: CGFloat = 0
                while x <= g.size.width + g.size.height {
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x - g.size.height, y: g.size.height))
                    x += step
                }
            }
            .stroke(Theme.protectedC.opacity(0.30), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private func marker(_ wp: WeakPoint, in size: CGSize) -> some View {
        let isSel = wp.id == selectedID
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedID = isSel ? nil : wp.id
            }
        }) {
            ZStack {
                Circle().fill(wp.status.color.opacity(0.22))
                    .frame(width: isSel ? 40 : 30, height: isSel ? 40 : 30)
                Circle().fill(wp.status.color)
                    .frame(width: isSel ? 24 : 18, height: isSel ? 24 : 18)
                    .shadow(color: wp.status == .exposed ? wp.status.color.opacity(0.9) : .clear, radius: 5)
                Image(systemName: wp.type.icon)
                    .font(.system(size: isSel ? 11 : 8, weight: .bold))
                    .foregroundColor(Theme.textOnAccent)
            }
            .overlay(Circle().stroke(Color.white.opacity(isSel ? 0.9 : 0), lineWidth: 1.5)
                        .frame(width: isSel ? 40 : 30, height: isSel ? 40 : 30))
        }
        .buttonStyle(PlainButtonStyle())
        .position(x: CGFloat(wp.mapX) * size.width, y: CGFloat(wp.mapY) * size.height)
    }

    // MARK: Buttons

    private var buttonRow: some View {
        HStack(spacing: 10) {
            ActionButton(title: "Add Point", systemImage: "plus", fullWidth: true) { sheet = .add }
            ActionButton(title: "Fix", systemImage: "checkmark.shield.fill", kind: .safe, fullWidth: true) { fixSelected() }
            ActionButton(title: "Inspect", systemImage: "magnifyingglass", kind: .secondary, fullWidth: true) { inspectSelected() }
        }
    }

    private func fixSelected() {
        guard let s = selected else { alert = .selectFirst; return }
        if s.isFixed { alert = .alreadyFixed; return }
        store.fixWeakPoint(s)
        alert = .fixed(s.zone.displayName)
    }
    private func inspectSelected() {
        guard let s = selected else { alert = .selectFirst; return }
        sheet = .edit(s)
    }

    private func selectionCard(_ s: WeakPoint) -> some View {
        CardView(tint: s.status.color.opacity(0.5)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: s.type.icon).foregroundColor(s.status.color)
                    Text(s.type.displayName).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                    Spacer()
                    TagChip(text: s.status.displayName, color: s.status.color, filled: true)
                }
                Text("\(s.zone.displayName) · \(s.priority.displayName) priority")
                    .font(Theme.caption()).foregroundColor(Theme.textSecondary)
                if !s.note.isEmpty {
                    Text(s.note).font(Theme.body()).foregroundColor(Theme.textPrimary)
                }
                if !s.remediation.isEmpty {
                    Label(s.remediation, systemImage: "wrench.and.screwdriver.fill")
                        .font(Theme.caption()).foregroundColor(Theme.protectedC)
                }
                HStack(spacing: 10) {
                    ActionButton(title: "Inspect / Edit", systemImage: "slider.horizontal.3", kind: .secondary) { sheet = .edit(s) }
                    if !s.isFixed {
                        ActionButton(title: "Fix", systemImage: "checkmark.shield.fill", kind: .safe) { fixSelected() }
                    }
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(ProtectionStatus.allCases) { st in
                HStack(spacing: 6) {
                    StatusDot(color: st.color, size: 9)
                    Text(st.displayName).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
        }
    }

    private var pointList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Weak points", systemImage: "list.bullet")
            if store.weakPoints.isEmpty {
                CardView { EmptyStateView(systemImage: "shield.slash", title: "No points yet",
                                          message: "Tap Add Point to map a gap, dig spot or weak mesh.") }
            } else {
                ForEach(store.weakPoints.sorted { $0.priority.sortOrder < $1.priority.sortOrder }) { wp in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedID = wp.id }
                    }) {
                        HStack(spacing: 12) {
                            StatusDot(color: wp.status.color, size: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(wp.type.displayName).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                                Text("\(wp.zone.displayName) · \(wp.priority.displayName)")
                                    .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            if wp.id == selectedID {
                                Image(systemName: "scope").foregroundColor(Theme.alarm)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.s)
                            .fill(wp.id == selectedID ? Theme.surfaceHi : Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private var defencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Defences", systemImage: "shield.checkerboard")
            NavRow(icon: "checklist", title: "Fix Checklist",
                   subtitle: "\(store.completedFixCount)/\(store.fixes.count) fortifications done",
                   tint: Theme.protectedC) { FixChecklistView() }
            NavRow(icon: "eye.fill", title: "Deterrents",
                   subtitle: "\(store.activeDeterrentCount) active", tint: Theme.dusk) { DeterrentsView() }
            NavRow(icon: "pawprint.fill", title: "Trap & Sightings",
                   subtitle: "\(store.sightings.count) logged", tint: Theme.moon) { TrapSightingView() }
        }
    }
}
