//
//  AppStore.swift
//  CoopWatch
//
//  The single source of truth (@EnvironmentObject). Holds AppData, exposes
//  uniform CRUD for every entity, the cached risk-by-time curve and all
//  cross-screen derived signals so numbers stay identical everywhere.
//  iOS 14 safe.
//

import SwiftUI

final class AppStore: ObservableObject {
    @Published private(set) var data: AppData

    private let persistence = PersistenceManager.shared
    private let photoStore = PhotoStore.shared

    // Risk curve cache (recomputed lazily, invalidated on mutation)
    private var riskCache: RiskResult?

    init() {
        self.data = persistence.load()
        resetNightRoutineIfNeeded()
    }

    // MARK: - Generic CRUD helpers

    private func upsert<T: Identifiable>(_ item: T, _ keyPath: WritableKeyPath<AppData, [T]>) where T.ID == UUID {
        if let i = data[keyPath: keyPath].firstIndex(where: { $0.id == item.id }) {
            data[keyPath: keyPath][i] = item
        } else {
            data[keyPath: keyPath].append(item)
        }
        save()
    }

    private func remove<T: Identifiable>(_ item: T, _ keyPath: WritableKeyPath<AppData, [T]>) where T.ID == UUID {
        data[keyPath: keyPath].removeAll { $0.id == item.id }
        save()
    }

    // MARK: - Coop profile

    var coop: CoopProfile { data.coop }
    func updateCoop(_ c: CoopProfile) {
        data.coop = c
        // Keep the lock-up reminder aligned to the coop's lock-up time.
        if let i = data.reminders.firstIndex(where: { $0.kind == .closeCoop }) {
            data.reminders[i].hour = c.lockUpHour
            data.reminders[i].minute = c.lockUpMinute
        }
        save()
    }

    // MARK: - Threats

    var threats: [ThreatProfile] { data.threats }
    var activeThreats: [ThreatProfile] { data.threats.filter { $0.isActive } }
    var selectedPredators: [PredatorType] { activeThreats.map { $0.predator } }

    func setThreatActive(_ predator: PredatorType, _ active: Bool) {
        if let i = data.threats.firstIndex(where: { $0.predator == predator }) {
            data.threats[i].isActive = active
        } else {
            data.threats.append(ThreatProfile(predator: predator, weight: 1.0, isActive: active))
        }
        save()
    }
    func setThreatWeight(_ predator: PredatorType, _ weight: Double) {
        if let i = data.threats.firstIndex(where: { $0.predator == predator }) {
            data.threats[i].weight = weight; save()
        }
    }
    func isThreatActive(_ predator: PredatorType) -> Bool {
        data.threats.first { $0.predator == predator }?.isActive ?? false
    }

    // MARK: - Collections

    var weakPoints: [WeakPoint] { data.weakPoints }
    var incidents: [AttackIncident] { data.incidents.sorted { $0.date > $1.date } }
    var losses: [BirdLoss] { data.losses }
    var fixes: [FixItem] { data.fixes }
    var nightTasks: [NightTask] { data.nightTasks }
    var deterrents: [Deterrent] { data.deterrents }
    var sightings: [Sighting] { data.sightings.sorted { $0.date > $1.date } }
    var photos: [PhotoEvidence] { data.photos }
    var reminders: [Reminder] { data.reminders.sorted { $0.kind.rawValue < $1.kind.rawValue } }

    // MARK: - CRUD per entity

    func saveWeakPoint(_ w: WeakPoint) { upsert(w, \.weakPoints) }
    func deleteWeakPoint(_ w: WeakPoint) { photoStore.delete(named: w.imageFileName); remove(w, \.weakPoints) }
    func fixWeakPoint(_ w: WeakPoint) {
        var copy = w; copy.status = .protectedNow; copy.resolvedAt = Date(); upsert(copy, \.weakPoints)
    }

    func saveIncident(_ i: AttackIncident) { upsert(i, \.incidents) }
    func deleteIncident(_ i: AttackIncident) { photoStore.delete(named: i.imageFileName); remove(i, \.incidents) }

    func saveLoss(_ l: BirdLoss) { upsert(l, \.losses) }
    func deleteLoss(_ l: BirdLoss) { remove(l, \.losses) }

    func saveFix(_ f: FixItem) { upsert(f, \.fixes) }
    func deleteFix(_ f: FixItem) { remove(f, \.fixes) }
    func toggleFix(_ f: FixItem) {
        var copy = f; copy.isDone.toggle(); copy.completedAt = copy.isDone ? Date() : nil; upsert(copy, \.fixes)
    }

    func saveNightTask(_ t: NightTask) { upsert(t, \.nightTasks) }
    func deleteNightTask(_ t: NightTask) { remove(t, \.nightTasks) }
    func toggleNightTask(_ t: NightTask) {
        var copy = t; copy.isDone.toggle(); upsert(copy, \.nightTasks)
    }
    func resetNightRoutine() {
        for i in data.nightTasks.indices { data.nightTasks[i].isDone = false }
        data.nightRoutineLastReset = Calendar.current.startOfDay(for: Date())
        save()
    }
    /// Clears the daily checklist automatically when a new day starts.
    func resetNightRoutineIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = data.nightRoutineLastReset, Calendar.current.isDate(last, inSameDayAs: today) { return }
        for i in data.nightTasks.indices { data.nightTasks[i].isDone = false }
        data.nightRoutineLastReset = today
        // No user-visible save needed urgently; debounce.
        persistence.save(data)
    }

    func saveDeterrent(_ d: Deterrent) { upsert(d, \.deterrents) }
    func deleteDeterrent(_ d: Deterrent) { remove(d, \.deterrents) }
    func toggleDeterrent(_ d: Deterrent) {
        var copy = d; copy.isActive.toggle(); upsert(copy, \.deterrents)
    }

    func saveSighting(_ s: Sighting) { upsert(s, \.sightings) }
    func deleteSighting(_ s: Sighting) { photoStore.delete(named: s.imageFileName); remove(s, \.sightings) }

    func savePhoto(_ p: PhotoEvidence) { upsert(p, \.photos) }
    func deletePhoto(_ p: PhotoEvidence) { photoStore.delete(named: p.imageFileName); remove(p, \.photos) }

    func saveReminder(_ r: Reminder) { upsert(r, \.reminders) }

    // MARK: - Perimeter derived

    var unresolvedWeakPoints: [WeakPoint] { data.weakPoints.filter { !$0.isFixed } }
    var exposedWeakPoints: [WeakPoint] { data.weakPoints.filter { $0.status == .exposed } }
    func weakPoints(status: ProtectionStatus) -> [WeakPoint] { data.weakPoints.filter { $0.status == status } }
    private func unresolvedCount(_ type: WeakPointType) -> Int {
        data.weakPoints.filter { !$0.isFixed && $0.type == type }.count
    }
    var hasOpenTopExposed: Bool { data.weakPoints.contains { !$0.isFixed && $0.type == .openTop } }

    /// 0…100 perimeter protection score.
    var perimeterScore: Double {
        guard !data.weakPoints.isEmpty else { return 100 }
        let total = data.weakPoints.count
        let fixed = data.weakPoints.filter { $0.isFixed }.count
        let atRisk = data.weakPoints.filter { $0.status == .atRisk }.count
        let raw = (Double(fixed) + Double(atRisk) * 0.5) / Double(total)
        return raw * 100
    }

    var activeDeterrentCount: Int { data.deterrents.filter { $0.isActive }.count }
    var completedFixCount: Int { data.fixes.filter { $0.isDone }.count }

    // MARK: - Risk engine (cached)

    var risk: RiskResult {
        if let cached = riskCache { return cached }
        let predators = activeThreats.map { (predator: $0.predator, weight: $0.weight) }
        let input = RiskInputs(
            predators: predators,
            incidents: data.incidents,
            sightings: data.sightings,
            setup: data.coop.setup,
            unresolvedGaps: unresolvedCount(.gap),
            unresolvedDig: unresolvedCount(.digSpot),
            unresolvedMesh: unresolvedCount(.weakMesh),
            unresolvedLatch: unresolvedCount(.looseLatch),
            hasOpenTopExposed: hasOpenTopExposed,
            activeDeterrents: activeDeterrentCount,
            completedFixes: completedFixCount,
            dawnHour: data.coop.dawnHour,
            duskHour: data.coop.duskHour
        )
        let result = RiskEngine.compute(input)
        riskCache = result
        return result
    }
    var currentRiskLevel: RiskLevel { risk.currentLevel }
    var mostDangerousHour: Int { risk.mostDangerousHour }

    // MARK: - Losses derived (incidents + standalone losses)

    /// Combined losses: predator losses come from incidents, plus standalone records.
    var combinedLosses: [BirdLoss] {
        let fromIncidents = data.incidents.filter { $0.birdsLost > 0 }.map {
            BirdLoss(id: $0.id, date: $0.date, count: $0.birdsLost, cause: .predator,
                     predator: $0.predator, note: $0.note)
        }
        return (fromIncidents + data.losses).sorted { $0.date > $1.date }
    }
    var totalBirdsLost: Int { combinedLosses.reduce(0) { $0 + $1.count } }
    func birdsLost(inLastDays days: Int) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return combinedLosses.filter { $0.date >= cutoff }.reduce(0) { $0 + $1.count }
    }
    func lossesByCause() -> [(cause: LossCause, count: Int)] {
        LossCause.allCases.map { cause in
            (cause, combinedLosses.filter { $0.cause == cause }.reduce(0) { $0 + $1.count })
        }.filter { $0.count > 0 }
    }
    func lossesByPredator() -> [(predator: PredatorType, count: Int)] {
        PredatorType.allCases.map { p in
            (p, combinedLosses.filter { $0.predator == p }.reduce(0) { $0 + $1.count })
        }.filter { $0.count > 0 }
    }
    /// Birds lost per week for the last `weeks` weeks (oldest → newest).
    func weeklyLossSeries(weeks: Int = 6) -> [Double] {
        let cal = Calendar.current
        let now = Date()
        return (0..<weeks).reversed().map { w in
            let end = cal.date(byAdding: .day, value: -7 * w, to: now) ?? now
            let start = cal.date(byAdding: .day, value: -7, to: end) ?? end
            return Double(combinedLosses.filter { $0.date > start && $0.date <= end }.reduce(0) { $0 + $1.count })
        }
    }

    func incidents(inLastDays days: Int) -> [AttackIncident] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return data.incidents.filter { $0.date >= cutoff }
    }

    // MARK: - Night routine derived

    var nightRoutineDone: Int { data.nightTasks.filter { $0.isDone }.count }
    var nightRoutineProgress: Double {
        guard !data.nightTasks.isEmpty else { return 0 }
        return Double(nightRoutineDone) / Double(data.nightTasks.count) * 100
    }
    var isCoopSecured: Bool { !data.nightTasks.isEmpty && nightRoutineDone == data.nightTasks.count }

    // MARK: - Dashboard badge

    /// Things needing attention, surfaced as a tab badge.
    var riskCount: Int {
        exposedWeakPoints.count + incidents(inLastDays: 7).count
    }

    // MARK: - Unified history timeline

    struct TimelineEntry: Identifiable {
        enum Kind { case attack, sighting, loss, fixed }
        let id = UUID()
        let date: Date
        let kind: Kind
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
    }

    func timeline() -> [TimelineEntry] {
        var entries: [TimelineEntry] = []
        for i in data.incidents {
            entries.append(TimelineEntry(date: i.date, kind: .attack,
                title: "\(i.predator.displayName) attack",
                subtitle: "\(i.zone.displayName) · \(i.entryMethod.displayName) · \(i.birdsLost) lost",
                icon: "exclamationmark.octagon.fill", color: Theme.attackC))
        }
        for s in data.sightings {
            entries.append(TimelineEntry(date: s.date, kind: .sighting,
                title: "\(s.evidence.displayName)\(s.predatorGuess.map { " · \($0.displayName)" } ?? "")",
                subtitle: "\(s.zone.displayName)\(s.nearbyActivity.isEmpty ? "" : " · \(s.nearbyActivity)")",
                icon: s.evidence.icon, color: Theme.dusk))
        }
        for l in data.losses {
            entries.append(TimelineEntry(date: l.date, kind: .loss,
                title: "Lost \(l.count) bird\(l.count == 1 ? "" : "s")",
                subtitle: "\(l.cause.displayName)\(l.note.isEmpty ? "" : " · \(l.note)")",
                icon: l.cause.icon, color: Theme.riskC))
        }
        for w in data.weakPoints where w.isFixed {
            entries.append(TimelineEntry(date: w.resolvedAt ?? w.createdAt, kind: .fixed,
                title: "Fixed: \(w.type.displayName)",
                subtitle: "\(w.zone.displayName)\(w.remediation.isEmpty ? "" : " · \(w.remediation)")",
                icon: "checkmark.shield.fill", color: Theme.protectedC))
        }
        return entries.sorted { $0.date > $1.date }
    }

    // MARK: - Lifecycle

    private func save() {
        riskCache = nil          // invalidate derived risk on any mutation
        persistence.save(data)
    }
    func flush() { persistence.flush(data) }

    func exportBackupURL() -> URL? { persistence.exportFile(data) }
    func importBackup(_ url: URL) -> Bool {
        guard let imported = persistence.importFile(url) else { return false }
        data = imported
        riskCache = nil
        persistence.saveNow(data)
        objectWillChange.send()
        return true
    }

    func resetToSampleData() {
        photoStore.clearAll()
        data = SampleData.make()
        riskCache = nil
        persistence.saveNow(data)
        objectWillChange.send()
    }

    func wipeAll() {
        photoStore.clearAll()
        data = AppData()
        // Re-seed the structural lists that are useless empty.
        data.threats = PredatorType.allCases.map { ThreatProfile(predator: $0, weight: 1.0, isActive: false) }
        data.reminders = ReminderKind.allCases.map {
            Reminder(kind: $0, isEnabled: false, hour: $0.defaultHour, minute: $0.defaultMinute)
        }
        riskCache = nil
        persistence.saveNow(data)
        objectWillChange.send()
    }
}
