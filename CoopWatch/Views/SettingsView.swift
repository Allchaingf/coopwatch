//
//  SettingsView.swift  (Screen 14 — Settings)
//  CoopWatch
//
//  Threats, coop setup, lock-up time, theme (dark/light/system applied app-wide
//  via @AppStorage + preferredColorScheme), backup export/import and data reset.
//  Every control writes through immediately. iOS 14 safe.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("appearance") private var appearanceRaw = AppAppearance.dark.rawValue

    @State private var sheet: SettingsSheet?
    @State private var importResult: ImportResult?
    @State private var confirmReset = false
    @State private var confirmWipe = false

    enum SettingsSheet: Identifiable {
        case share(URL), importDoc
        var id: String { switch self { case .share(let u): return u.absoluteString; case .importDoc: return "import" } }
    }
    struct ImportResult: Identifiable { let id = UUID(); let ok: Bool }

    var body: some View {
        ScreenScaffold("Settings", subtitle: "Tune threats, defences & data", showFence: false) {
            threatsCard
            coopCard
            themeCard
            backupCard
            dataCard
            aboutCard
        }
        .sheet(item: $sheet) { route in
            switch route {
            case .share(let url): ShareSheet(items: [url])
            case .importDoc:
                JSONDocumentPicker { url in
                    let ok = store.importBackup(url)
                    importResult = ImportResult(ok: ok)
                }
            }
        }
        .alert(item: $importResult) { r in
            r.ok ? Alert(title: Text("Backup restored"), message: Text("Your coop data was imported."), dismissButton: .default(Text("OK")))
                 : Alert(title: Text("Import failed"), message: Text("That file wasn't a valid Coop Watch backup."), dismissButton: .default(Text("OK")))
        }
        .alert(isPresented: $confirmReset) {
            Alert(title: Text("Reset to sample data?"),
                  message: Text("Replaces everything with the demo coop. This can't be undone."),
                  primaryButton: .destructive(Text("Reset")) { store.resetToSampleData() },
                  secondaryButton: .cancel())
        }
    }

    // MARK: Threats

    private var threatsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Threats", subtitle: "Drives the risk clock", systemImage: "pawprint.fill")
                ForEach(PredatorType.allCases) { p in
                    let isOn = store.isThreatActive(p)
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: p.icon).foregroundColor(isOn ? p.tint : Theme.textSecondary).frame(width: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(p.displayName).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                                Text(p.blurb).font(Theme.caption(10)).foregroundColor(Theme.textSecondary).lineLimit(1)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(get: { isOn }, set: { store.setThreatActive(p, $0) }))
                                .labelsHidden().toggleStyle(SwitchToggleStyle(tint: p.tint))
                        }
                        if isOn {
                            HStack(spacing: 10) {
                                Text("Concern").font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                                Slider(value: Binding(
                                    get: { store.threats.first { $0.predator == p }?.weight ?? 1.0 },
                                    set: { store.setThreatWeight(p, $0) }), in: 0.5...1.5, step: 0.1)
                                    .accentColor(p.tint)
                                Text(weightLabel(store.threats.first { $0.predator == p }?.weight ?? 1.0))
                                    .font(Theme.caption(10)).foregroundColor(p.tint).frame(width: 44, alignment: .trailing)
                            }
                        }
                    }
                    if p != PredatorType.allCases.last { Divider().background(Theme.stroke) }
                }
            }
        }
    }
    private func weightLabel(_ w: Double) -> String {
        if w < 0.8 { return "Low" }; if w > 1.2 { return "High" }; return "Normal"
    }

    // MARK: Coop

    private var coopCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                SectionHeader(title: "Coop Setup", systemImage: "house.fill")
                EnumMenu(title: "Layout", selection: coopSetupBinding, options: CoopSetup.allCases) { $0.displayName }

                VStack(alignment: .leading, spacing: 6) {
                    HStack { FieldLabel(text: "Fence length"); Spacer()
                        Text("\(Int(store.coop.fenceLengthMeters)) m").font(Theme.caption()).foregroundColor(Theme.dusk) }
                    Slider(value: Binding(get: { store.coop.fenceLengthMeters },
                                          set: { var c = store.coop; c.fenceLengthMeters = $0; store.updateCoop(c) }),
                           in: 5...120, step: 1).accentColor(Theme.alarm)
                }

                Toggle(isOn: Binding(get: { store.coop.hasDigSkirt },
                                     set: { var c = store.coop; c.hasDigSkirt = $0; store.updateCoop(c) })) {
                    Label("Dig skirt / apron buried", systemImage: "arrow.down.to.line").font(Theme.body()).foregroundColor(Theme.textPrimary)
                }.toggleStyle(SwitchToggleStyle(tint: Theme.protectedC))

                Toggle(isOn: Binding(get: { store.coop.hasTopNet },
                                     set: { var c = store.coop; c.hasTopNet = $0; store.updateCoop(c) })) {
                    Label("Mesh / net over the top", systemImage: "grid").font(Theme.body()).foregroundColor(Theme.textPrimary)
                }.toggleStyle(SwitchToggleStyle(tint: Theme.protectedC))

                HStack {
                    FieldLabel(text: "Lock-up time"); Spacer()
                    DatePicker("", selection: lockUpBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden().accentColor(Theme.alarm)
                }
                HStack(spacing: 12) {
                    hourStepper(title: "Dawn", value: Binding(
                        get: { store.coop.dawnHour }, set: { var c = store.coop; c.dawnHour = $0; store.updateCoop(c) }))
                    hourStepper(title: "Dusk", value: Binding(
                        get: { store.coop.duskHour }, set: { var c = store.coop; c.duskHour = $0; store.updateCoop(c) }))
                }
                LabeledNumberField(label: "Flock size", value: Binding(
                    get: { store.coop.birdCount }, set: { var c = store.coop; c.birdCount = $0; store.updateCoop(c) }), suffix: "birds")
            }
        }
    }

    private var coopSetupBinding: Binding<CoopSetup> {
        Binding(get: { store.coop.setup }, set: { var c = store.coop; c.setup = $0; store.updateCoop(c) })
    }
    private var lockUpBinding: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents(); c.hour = store.coop.lockUpHour; c.minute = store.coop.lockUpMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { d in
                var c = store.coop
                c.lockUpHour = Calendar.current.component(.hour, from: d)
                c.lockUpMinute = Calendar.current.component(.minute, from: d)
                store.updateCoop(c)
            })
    }
    private func hourStepper(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            FieldLabel(text: title)
            HStack {
                Button(action: { value.wrappedValue = max(0, value.wrappedValue - 1) }) {
                    Image(systemName: "minus.circle.fill").foregroundColor(Theme.textSecondary)
                }.buttonStyle(PlainButtonStyle())
                Spacer()
                Text(Formatters.hourLabel(value.wrappedValue)).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: { value.wrappedValue = min(23, value.wrappedValue + 1) }) {
                    Image(systemName: "plus.circle.fill").foregroundColor(Theme.dusk)
                }.buttonStyle(PlainButtonStyle())
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Theme

    private var themeCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Appearance", subtitle: "Night by default", systemImage: "moon.fill")
                HStack(spacing: 10) {
                    ForEach(AppAppearance.allCases) { a in
                        Button(action: { withAnimation { appearanceRaw = a.rawValue } }) {
                            VStack(spacing: 6) {
                                Image(systemName: a.icon).font(.system(size: 18, weight: .bold))
                                Text(a.displayName).font(Theme.caption(12))
                            }
                            .foregroundColor(appearanceRaw == a.rawValue ? Theme.textOnAccent : Theme.textPrimary)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.s)
                                .fill(appearanceRaw == a.rawValue ? Theme.alarm : Theme.surfaceAlt))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: Backup

    private var backupCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Backup", subtitle: "Export or restore a JSON file", systemImage: "externaldrive.fill")
                HStack(spacing: 10) {
                    ActionButton(title: "Export", systemImage: "square.and.arrow.up", kind: .secondary) {
                        if let url = store.exportBackupURL() { sheet = .share(url) }
                    }
                    ActionButton(title: "Import", systemImage: "square.and.arrow.down", kind: .secondary) {
                        sheet = .importDoc
                    }
                }
            }
        }
    }

    // MARK: Data

    private var dataCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Data", systemImage: "trash")
                ActionButton(title: "Load sample coop", systemImage: "arrow.counterclockwise", kind: .secondary) { confirmReset = true }
                ActionButton(title: "Erase everything", systemImage: "trash.fill", kind: .danger) { confirmWipe = true }
            }
        }
        .alert(isPresented: $confirmWipe) {
            Alert(title: Text("Erase all data?"),
                  message: Text("Removes every weak point, incident, photo and setting. This can't be undone."),
                  primaryButton: .destructive(Text("Erase")) { store.wipeAll() },
                  secondaryButton: .cancel())
        }
    }

    private var aboutCard: some View {
        CardView {
            HStack(spacing: 12) {
                MoonView(size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Coop Watch").font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                    Text("Lock the coop before dusk. · Local & offline · v1.0")
                        .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
        }
    }
}
