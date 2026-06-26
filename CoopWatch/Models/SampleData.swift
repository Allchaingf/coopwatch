//
//  SampleData.swift
//  CoopWatch
//
//  First-launch seed: a realistic backyard with selected threats, a perimeter
//  of weak points, a few attacks spread across dawn/dusk hours (so the Risk
//  Clock has shape immediately), deterrents, the standard fortification list,
//  a night routine and the three reminder slots.
//

import Foundation

enum SampleData {

    static func make() -> AppData {
        var d = AppData()

        d.coop = CoopProfile(setup: .openRun, fenceLengthMeters: 32, hasDigSkirt: false,
                             hasTopNet: false, lockUpHour: 19, lockUpMinute: 0,
                             dawnHour: 6, duskHour: 20, birdCount: 7)

        d.threats = [
            ThreatProfile(predator: .fox, weight: 1.2, isActive: true),
            ThreatProfile(predator: .raccoon, weight: 1.0, isActive: true),
            ThreatProfile(predator: .hawk, weight: 0.9, isActive: true),
            ThreatProfile(predator: .weasel, weight: 1.0, isActive: false),
            ThreatProfile(predator: .strayDog, weight: 1.0, isActive: false),
            ThreatProfile(predator: .snake, weight: 1.0, isActive: false)
        ]

        d.weakPoints = [
            WeakPoint(type: .digSpot, zone: .north, priority: .high, status: .exposed,
                      note: "Loose soil where the soil meets the post.",
                      remediation: "Bury a 30cm hardware-cloth skirt.",
                      mapX: 0.50, mapY: 0.10, createdAt: daysAgo(8)),
            WeakPoint(type: .weakMesh, zone: .run, priority: .urgent, status: .exposed,
                      note: "Chicken wire stretched — a raccoon could tear it.",
                      remediation: "Replace with 1/2\" hardware cloth.",
                      mapX: 0.66, mapY: 0.58, createdAt: daysAgo(14)),
            WeakPoint(type: .openTop, zone: .run, priority: .high, status: .atRisk,
                      note: "Run is open to the sky — hawk exposure midday.",
                      remediation: "String overhead netting.",
                      mapX: 0.74, mapY: 0.42, createdAt: daysAgo(20)),
            WeakPoint(type: .gap, zone: .east, priority: .medium, status: .atRisk,
                      note: "Small gap under the east gate post.",
                      remediation: "Pack with gravel + mesh.",
                      mapX: 0.90, mapY: 0.52, createdAt: daysAgo(5)),
            WeakPoint(type: .looseLatch, zone: .gate, priority: .low, status: .protectedNow,
                      note: "Old latch a raccoon could flip.",
                      remediation: "Fitted a spring carabiner lock.",
                      mapX: 0.50, mapY: 0.90, createdAt: daysAgo(30), resolvedAt: daysAgo(2))
        ]

        d.incidents = [
            AttackIncident(predator: .fox, date: at(daysAgo: 3, hour: 5, minute: 20), zone: .north,
                           entryMethod: .dugUnder, birdsLost: 2, note: "Dug under the north fence at dawn.",
                           createdAt: at(daysAgo: 3, hour: 6, minute: 0)),
            AttackIncident(predator: .fox, date: at(daysAgo: 9, hour: 20, minute: 40), zone: .run,
                           entryMethod: .squeezedGap, birdsLost: 1, note: "Came in at dusk before lock-up.",
                           createdAt: at(daysAgo: 9, hour: 21, minute: 0)),
            AttackIncident(predator: .raccoon, date: at(daysAgo: 16, hour: 23, minute: 10), zone: .run,
                           entryMethod: .brokeMesh, birdsLost: 1, note: "Tore the run mesh overnight.",
                           createdAt: at(daysAgo: 16, hour: 7, minute: 0)),
            AttackIncident(predator: .hawk, date: at(daysAgo: 24, hour: 9, minute: 30), zone: .run,
                           entryMethod: .fromAbove, birdsLost: 1, note: "Swooped into the open run.",
                           createdAt: at(daysAgo: 24, hour: 10, minute: 0))
        ]

        d.losses = [
            BirdLoss(date: at(daysAgo: 12, hour: 8, minute: 0), count: 1, cause: .illness,
                     predator: nil, note: "Found unwell in the morning."),
            BirdLoss(date: at(daysAgo: 28, hour: 17, minute: 0), count: 1, cause: .escape,
                     predator: nil, note: "Flew the fence, never returned.")
        ]

        d.fixes = [
            FixItem(title: "Bury a dig apron / skirt", detail: "30–40cm hardware cloth folded outward along the base.",
                    category: .digSpot, isDone: false, icon: "arrow.down.to.line"),
            FixItem(title: "Add overhead netting", detail: "Cover the open run against hawks.",
                    category: .openTop, isDone: false, icon: "grid"),
            FixItem(title: "Predator-proof door locks", detail: "Two-step latches / carabiners raccoons can't open.",
                    category: .looseLatch, isDone: true, completedAt: daysAgo(2), icon: "lock.fill"),
            FixItem(title: "Motion light + sensor", detail: "Startle night predators near the run.",
                    category: nil, isDone: true, completedAt: daysAgo(6), icon: "lightbulb.fill"),
            FixItem(title: "Upgrade to 1/2\" hardware cloth", detail: "Replace chicken wire on the run walls.",
                    category: .weakMesh, isDone: false, icon: "square.grid.3x3.fill")
        ]

        d.nightTasks = [
            NightTask(title: "All birds inside the coop", icon: "bird.fill"),
            NightTask(title: "Coop door shut & latched", icon: "lock.fill"),
            NightTask(title: "Run gate locked", icon: "door.left.hand.closed"),
            NightTask(title: "Feed stored (no rodent lure)", icon: "shippingbox.fill"),
            NightTask(title: "Motion light / trap armed", icon: "lightbulb.fill"),
            NightTask(title: "Head-count matches", icon: "checklist")
        ]
        d.nightRoutineLastReset = Calendar.current.startOfDay(for: Date())

        d.deterrents = [
            Deterrent(type: .motionLight, zone: .run, isActive: true, note: "Solar PIR light over the run.",
                      installedAt: daysAgo(40)),
            Deterrent(type: .predatorEyes, zone: .north, isActive: true, note: "Red solar eyes on the north post.",
                      installedAt: daysAgo(18)),
            Deterrent(type: .radio, zone: .coop, isActive: false, note: "Talk radio at dusk — currently off.",
                      installedAt: daysAgo(60))
        ]

        d.sightings = [
            Sighting(evidence: .pawPrints, date: daysAgo(2), zone: .north, predatorGuess: .fox,
                     nearbyActivity: "Fresh prints in the mud by the dig spot.",
                     note: "Pointing toward the coop."),
            Sighting(evidence: .droppings, date: daysAgo(6), zone: .east, predatorGuess: .raccoon,
                     nearbyActivity: "Scat on the east gate rail.", note: "")
        ]

        d.reminders = ReminderKind.allCases.map {
            Reminder(kind: $0, isEnabled: false, hour: $0.defaultHour, minute: $0.defaultMinute)
        }
        // The lock-up reminder mirrors the coop's lock-up time by default.
        if let i = d.reminders.firstIndex(where: { $0.kind == .closeCoop }) {
            d.reminders[i].hour = d.coop.lockUpHour
            d.reminders[i].minute = d.coop.lockUpMinute
        }

        return d
    }

    // MARK: - Date helpers

    private static func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date()) ?? Date()
    }
    private static func at(daysAgo n: Int, hour: Int, minute: Int) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: -n, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }
}
