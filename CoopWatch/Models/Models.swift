//
//  Models.swift
//  CoopWatch
//
//  Every data structure for the app: predator/threat enums (with diurnal
//  activity curves that drive the risk engine), perimeter weak points, attack
//  incidents, losses, fortifications, night routine, deterrents, sightings,
//  photo evidence, reminders — and the single Codable `AppData` root.
//  All value types, all iOS 14 safe.
//

import SwiftUI

// MARK: - Predator types (carry a 24-hour diurnal activity curve)

enum PredatorType: String, Codable, CaseIterable, Identifiable {
    case fox, hawk, raccoon, weasel, strayDog, snake
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fox: return "Fox"
        case .hawk: return "Hawk"
        case .raccoon: return "Raccoon"
        case .weasel: return "Weasel"
        case .strayDog: return "Stray Dog"
        case .snake: return "Snake"
        }
    }
    var icon: String {
        switch self {
        case .fox: return "pawprint.fill"
        case .hawk: return "bird.fill"
        case .raccoon: return "pawprint.circle.fill"
        case .weasel: return "hare.fill"
        case .strayDog: return "dog.fill"
        case .snake: return "scribble.variable"
        }
    }
    var tint: Color {
        switch self {
        case .fox: return Theme.dusk
        case .hawk: return Theme.moon
        case .raccoon: return Color(hex: 0xA78BFA)
        case .weasel: return Color(hex: 0xF59E0B)
        case .strayDog: return Color(hex: 0xF87171)
        case .snake: return Theme.protectedC
        }
    }
    var blurb: String {
        switch self {
        case .fox: return "Crepuscular & nocturnal — strikes at dawn and dusk."
        case .hawk: return "Diurnal raptor — hunts from above in daylight."
        case .raccoon: return "Nocturnal — peaks around midnight, dexterous paws."
        case .weasel: return "Active around the clock, squeezes tiny gaps."
        case .strayDog: return "Roams mornings & evenings when no one's around."
        case .snake: return "Warm-daylight hunter — after eggs and chicks."
        }
    }

    /// Relative hourly activity 0…1 (index 0…23). Normalised inside the engine.
    var diurnalCurve: [Double] {
        switch self {
        case .fox:
            return [0.55,0.50,0.45,0.50,0.80,0.95,0.85,0.50,0.30,0.18,0.12,0.10,
                    0.10,0.10,0.12,0.18,0.30,0.50,0.80,0.95,1.00,0.90,0.75,0.60]
        case .hawk:
            return [0.00,0.00,0.00,0.00,0.00,0.05,0.25,0.70,0.95,1.00,0.80,0.60,
                    0.50,0.50,0.60,0.80,0.95,0.90,0.60,0.25,0.05,0.00,0.00,0.00]
        case .raccoon:
            return [0.95,0.90,0.85,0.70,0.50,0.30,0.15,0.05,0.02,0.00,0.00,0.00,
                    0.00,0.00,0.00,0.02,0.05,0.10,0.25,0.50,0.75,0.90,1.00,0.98]
        case .weasel:
            return [0.35,0.35,0.35,0.38,0.50,0.70,0.75,0.65,0.50,0.45,0.42,0.40,
                    0.40,0.42,0.45,0.48,0.55,0.65,0.72,0.68,0.55,0.45,0.40,0.38]
        case .strayDog:
            return [0.30,0.25,0.22,0.25,0.40,0.65,0.80,0.75,0.55,0.45,0.40,0.40,
                    0.42,0.42,0.45,0.50,0.60,0.75,0.85,0.80,0.60,0.45,0.38,0.33]
        case .snake:
            return [0.00,0.00,0.00,0.00,0.00,0.05,0.15,0.35,0.60,0.85,1.00,0.95,
                    0.85,0.80,0.82,0.85,0.80,0.70,0.50,0.30,0.12,0.04,0.00,0.00]
        }
    }
}

// MARK: - Coop setup

enum CoopSetup: String, Codable, CaseIterable, Identifiable {
    case openRun, closedRun, freeRange
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .openRun: return "Open Run"
        case .closedRun: return "Closed Run"
        case .freeRange: return "Free Range"
        }
    }
    var icon: String {
        switch self {
        case .openRun: return "square.dashed"
        case .closedRun: return "square.grid.3x3.fill"
        case .freeRange: return "leaf.fill"
        }
    }
    var blurb: String {
        switch self {
        case .openRun: return "Fenced run, open to the sky. Watch for raptors."
        case .closedRun: return "Fully enclosed run with mesh top. Best protected."
        case .freeRange: return "Birds roam freely — hardest to defend."
        }
    }
    /// Baseline risk multiplier for the engine.
    var riskMultiplier: Double {
        switch self {
        case .openRun: return 1.0
        case .closedRun: return 0.8
        case .freeRange: return 1.35
        }
    }
}

// MARK: - Perimeter zones (each has a default position on the map, 0…1)

enum Zone: String, Codable, CaseIterable, Identifiable {
    case north, east, south, west, gate, coop, run
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .north: return "North Fence"
        case .east: return "East Fence"
        case .south: return "South Fence"
        case .west: return "West Fence"
        case .gate: return "Gate"
        case .coop: return "Coop"
        case .run: return "Run"
        }
    }
    var short: String {
        switch self {
        case .north: return "N"; case .east: return "E"; case .south: return "S"
        case .west: return "W"; case .gate: return "Gate"; case .coop: return "Coop"; case .run: return "Run"
        }
    }
    /// Default normalised position used when a new point is added to this zone.
    var anchor: CGPoint {
        switch self {
        case .north: return CGPoint(x: 0.5, y: 0.10)
        case .south: return CGPoint(x: 0.5, y: 0.90)
        case .west:  return CGPoint(x: 0.10, y: 0.5)
        case .east:  return CGPoint(x: 0.90, y: 0.5)
        case .gate:  return CGPoint(x: 0.5, y: 0.90)
        case .coop:  return CGPoint(x: 0.32, y: 0.34)
        case .run:   return CGPoint(x: 0.62, y: 0.6)
        }
    }
}

// MARK: - Weak point type & protection status

enum WeakPointType: String, Codable, CaseIterable, Identifiable {
    case gap, digSpot, weakMesh, openTop, looseLatch
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .gap: return "Gap / Hole"
        case .digSpot: return "Dig Spot"
        case .weakMesh: return "Weak Mesh"
        case .openTop: return "Open Top"
        case .looseLatch: return "Loose Latch"
        }
    }
    var icon: String {
        switch self {
        case .gap: return "circle.dashed"
        case .digSpot: return "arrow.down.to.line"
        case .weakMesh: return "grid"
        case .openTop: return "rectangle.portrait.and.arrow.right"
        case .looseLatch: return "lock.open.fill"
        }
    }
    var fixHint: String {
        switch self {
        case .gap: return "Patch with hardware cloth"
        case .digSpot: return "Bury a dig apron / skirt"
        case .weakMesh: return "Replace with 1/2\" hardware cloth"
        case .openTop: return "Add overhead netting"
        case .looseLatch: return "Fit a predator-proof lock"
        }
    }
}

enum ProtectionStatus: String, Codable, CaseIterable, Identifiable {
    case exposed, atRisk, protectedNow
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .exposed: return "Exposed"
        case .atRisk: return "At Risk"
        case .protectedNow: return "Protected"
        }
    }
    var color: Color {
        switch self {
        case .exposed: return Theme.attackC
        case .atRisk: return Theme.riskC
        case .protectedNow: return Theme.protectedC
        }
    }
    var icon: String {
        switch self {
        case .exposed: return "exclamationmark.octagon.fill"
        case .atRisk: return "exclamationmark.triangle.fill"
        case .protectedNow: return "checkmark.shield.fill"
        }
    }
}

// MARK: - Priority

enum Priority: String, Codable, CaseIterable, Identifiable {
    case low, medium, high, urgent
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var sortOrder: Int {
        switch self { case .urgent: return 0; case .high: return 1; case .medium: return 2; case .low: return 3 }
    }
    var color: Color {
        switch self {
        case .low: return Theme.calmNight
        case .medium: return Theme.moon
        case .high: return Theme.riskC
        case .urgent: return Theme.attackC
        }
    }
}

// MARK: - Entry method (how a predator got in)

enum EntryMethod: String, Codable, CaseIterable, Identifiable {
    case dugUnder, climbedOver, squeezedGap, openDoor, brokeMesh, fromAbove, unknown
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .dugUnder: return "Dug under"
        case .climbedOver: return "Climbed over"
        case .squeezedGap: return "Squeezed through gap"
        case .openDoor: return "Open door / latch"
        case .brokeMesh: return "Broke the mesh"
        case .fromAbove: return "From above"
        case .unknown: return "Unknown"
        }
    }
    var icon: String {
        switch self {
        case .dugUnder: return "arrow.down.to.line"
        case .climbedOver: return "arrow.up.forward"
        case .squeezedGap: return "circle.dashed"
        case .openDoor: return "door.left.hand.open"
        case .brokeMesh: return "grid"
        case .fromAbove: return "arrow.down.circle"
        case .unknown: return "questionmark"
        }
    }
}

// MARK: - Loss cause

enum LossCause: String, Codable, CaseIterable, Identifiable {
    case predator, illness, escape, unknown
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .predator: return "pawprint.fill"
        case .illness: return "cross.case.fill"
        case .escape: return "figure.walk"
        case .unknown: return "questionmark.circle"
        }
    }
    var color: Color {
        switch self {
        case .predator: return Theme.attackC
        case .illness: return Theme.dusk
        case .escape: return Theme.calmNight
        case .unknown: return Theme.textSecondary
        }
    }
}

// MARK: - Deterrents

enum DeterrentType: String, Codable, CaseIterable, Identifiable {
    case motionLight, radio, predatorEyes, sprinkler, scarecrow, guardAnimal
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .motionLight: return "Motion Light"
        case .radio: return "Radio / Sound"
        case .predatorEyes: return "Predator Eyes"
        case .sprinkler: return "Motion Sprinkler"
        case .scarecrow: return "Scarecrow / Decoy"
        case .guardAnimal: return "Guard Animal"
        }
    }
    var icon: String {
        switch self {
        case .motionLight: return "lightbulb.fill"
        case .radio: return "radio.fill"
        case .predatorEyes: return "eye.fill"
        case .sprinkler: return "drop.fill"
        case .scarecrow: return "figure.stand"
        case .guardAnimal: return "dog.fill"
        }
    }
}

// MARK: - Sighting evidence

enum SightingEvidence: String, Codable, CaseIterable, Identifiable {
    case tracks, droppings, pawPrints, sounds, fur, feathers, kill, burrow
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .tracks: return "Tracks"
        case .droppings: return "Droppings"
        case .pawPrints: return "Paw Prints"
        case .sounds: return "Sounds"
        case .fur: return "Fur / Hair"
        case .feathers: return "Scattered Feathers"
        case .kill: return "Kill Site"
        case .burrow: return "Burrow / Dig"
        }
    }
    var icon: String {
        switch self {
        case .tracks: return "shoeprints.fill"
        case .droppings: return "circle.grid.2x1.fill"
        case .pawPrints: return "pawprint.fill"
        case .sounds: return "waveform"
        case .fur: return "scribble"
        case .feathers: return "leaf.fill"
        case .kill: return "exclamationmark.octagon.fill"
        case .burrow: return "arrow.down.to.line"
        }
    }
}

// MARK: - Reminders

enum ReminderKind: String, Codable, CaseIterable, Identifiable {
    case closeCoop, checkPerimeter, reconfigureDeterrent
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .closeCoop: return "Close the coop"
        case .checkPerimeter: return "Check the perimeter"
        case .reconfigureDeterrent: return "Move a deterrent"
        }
    }
    var blurb: String {
        switch self {
        case .closeCoop: return "Evening lock-up before dusk."
        case .checkPerimeter: return "Walk the fence for new weak spots."
        case .reconfigureDeterrent: return "Relocate lights/decoys so predators don't habituate."
        }
    }
    var icon: String {
        switch self {
        case .closeCoop: return "lock.fill"
        case .checkPerimeter: return "figure.walk.motion"
        case .reconfigureDeterrent: return "arrow.triangle.2.circlepath"
        }
    }
    var notifID: String { "com.CoopingWatched.CoopWatch.reminder.\(rawValue)" }
    var defaultHour: Int {
        switch self { case .closeCoop: return 19; case .checkPerimeter: return 9; case .reconfigureDeterrent: return 11 }
    }
    var defaultMinute: Int { 0 }
    var notifBody: String {
        switch self {
        case .closeCoop: return "Are all birds inside and the door locked for the night?"
        case .checkPerimeter: return "Walk the fence — look for fresh dig spots and gaps."
        case .reconfigureDeterrent: return "Move a light or decoy so predators don't get used to it."
        }
    }
}

// MARK: - Risk level

enum RiskLevel: String, Codable {
    case calm, watch, risk, attack
    var displayName: String {
        switch self {
        case .calm: return "Calm Night"
        case .watch: return "On Watch"
        case .risk: return "Elevated Risk"
        case .attack: return "High Danger"
        }
    }
    var color: Color {
        switch self {
        case .calm: return Theme.calmNight
        case .watch: return Theme.moon
        case .risk: return Theme.riskC
        case .attack: return Theme.attackC
        }
    }
    var icon: String {
        switch self {
        case .calm: return "moon.zzz.fill"
        case .watch: return "eye.fill"
        case .risk: return "exclamationmark.triangle.fill"
        case .attack: return "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Structs

struct CoopProfile: Codable, Equatable {
    var setup: CoopSetup = .openRun
    var fenceLengthMeters: Double = 30
    var hasDigSkirt: Bool = false
    var hasTopNet: Bool = false
    var lockUpHour: Int = 19
    var lockUpMinute: Int = 0
    var dawnHour: Int = 6
    var duskHour: Int = 20
    var birdCount: Int = 6
}

struct ThreatProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var predator: PredatorType
    var weight: Double = 1.0   // 0.5 (low concern) … 1.5 (high concern)
    var isActive: Bool = true
}

struct WeakPoint: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: WeakPointType
    var zone: Zone
    var priority: Priority = .medium
    var status: ProtectionStatus = .exposed
    var note: String = ""
    var remediation: String = ""
    var imageFileName: String? = nil
    var mapX: Double = 0.5
    var mapY: Double = 0.5
    var createdAt: Date = Date()
    var resolvedAt: Date? = nil

    var isFixed: Bool { status == .protectedNow }
}

struct AttackIncident: Identifiable, Codable, Equatable {
    var id = UUID()
    var predator: PredatorType = .fox
    var date: Date = Date()
    var zone: Zone = .run
    var entryMethod: EntryMethod = .unknown
    var birdsLost: Int = 0
    var note: String = ""
    var imageFileName: String? = nil
    var createdAt: Date = Date()

    var hour: Int { Calendar.current.component(.hour, from: date) }
}

struct BirdLoss: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date = Date()
    var count: Int = 1
    var cause: LossCause = .predator
    var predator: PredatorType? = nil
    var note: String = ""
}

struct FixItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var detail: String = ""
    var category: WeakPointType? = nil
    var isDone: Bool = false
    var completedAt: Date? = nil
    var icon: String = "wrench.and.screwdriver.fill"
}

struct NightTask: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var icon: String = "checkmark.circle"
    var isDone: Bool = false
}

struct Deterrent: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: DeterrentType
    var zone: Zone = .run
    var isActive: Bool = true
    var note: String = ""
    var installedAt: Date = Date()
}

struct Sighting: Identifiable, Codable, Equatable {
    var id = UUID()
    var evidence: SightingEvidence = .tracks
    var date: Date = Date()
    var zone: Zone = .north
    var predatorGuess: PredatorType? = nil
    var nearbyActivity: String = ""
    var note: String = ""
    var imageFileName: String? = nil
}

struct PhotoEvidence: Identifiable, Codable, Equatable {
    var id = UUID()
    var caption: String = ""
    var tag: String = ""
    var imageFileName: String? = nil
    var markerX: Double = 0.5
    var markerY: Double = 0.5
    var createdAt: Date = Date()
}

struct Reminder: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: ReminderKind
    var isEnabled: Bool = false
    var hour: Int
    var minute: Int
}

// MARK: - Root persisted document

struct AppData: Codable {
    var schemaVersion: Int = 1
    var coop = CoopProfile()
    var threats: [ThreatProfile] = []
    var weakPoints: [WeakPoint] = []
    var incidents: [AttackIncident] = []
    var losses: [BirdLoss] = []
    var fixes: [FixItem] = []
    var nightTasks: [NightTask] = []
    var nightRoutineLastReset: Date? = nil
    var deterrents: [Deterrent] = []
    var sightings: [Sighting] = []
    var photos: [PhotoEvidence] = []
    var reminders: [Reminder] = []
}
