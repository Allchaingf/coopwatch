//
//  RiskEngine.swift
//  CoopWatch
//
//  The unique core: builds a 24-hour attack-risk curve by blending each
//  selected predator's diurnal activity with the recency-weighted incident
//  history, then scaling by coop setup, unresolved perimeter weaknesses,
//  active deterrents and completed fortifications. Pure Foundation, no SwiftUI
//  — deterministic and unit-testable. iOS 14 safe.
//

import Foundation

struct RiskHour: Identifiable {
    let id: Int          // == hour
    let hour: Int        // 0…23
    let score: Double    // 0…100
    var isDawnPeak: Bool = false
    var isDuskPeak: Bool = false
}

struct RiskResult {
    var hours: [RiskHour]           // always 24
    var mostDangerousHour: Int
    var dawnPeakHour: Int
    var duskPeakHour: Int

    func score(at hour: Int) -> Double {
        let h = ((hour % 24) + 24) % 24
        return hours[h].score
    }
    var currentLevel: RiskLevel {
        RiskEngine.level(for: score(at: Calendar.current.component(.hour, from: Date())))
    }
    static var empty: RiskResult {
        RiskResult(hours: (0..<24).map { RiskHour(id: $0, hour: $0, score: 0) },
                   mostDangerousHour: 0, dawnPeakHour: 6, duskPeakHour: 20)
    }
}

/// Inputs gathered by the store and handed to the pure engine.
struct RiskInputs {
    var predators: [(predator: PredatorType, weight: Double)]
    var incidents: [AttackIncident]
    var sightings: [Sighting]
    var setup: CoopSetup
    var unresolvedGaps: Int
    var unresolvedDig: Int
    var unresolvedMesh: Int
    var unresolvedLatch: Int
    var hasOpenTopExposed: Bool
    var activeDeterrents: Int
    var completedFixes: Int
    var dawnHour: Int
    var duskHour: Int
}

enum RiskEngine {

    private static let expectedMax = 1.6   // tuning constant for absolute scaling

    static func compute(_ input: RiskInputs, now: Date = Date()) -> RiskResult {
        // --- Step 1: predator activity term P[h] = max over selected predators ---
        var P = [Double](repeating: 0, count: 24)
        for (predator, weight) in input.predators {
            let curve = predator.diurnalCurve
            for h in 0..<24 { P[h] = max(P[h], curve[h] * weight) }
        }

        // --- Step 2: recency-weighted history term H[h] ---
        var rawH = [Double](repeating: 0, count: 24)
        let cal = Calendar.current
        for inc in input.incidents {
            let days = max(0, cal.dateComponents([.day], from: inc.date, to: now).day ?? 0)
            rawH[inc.hour] += exp(-Double(days) / 60.0)
        }
        for s in input.sightings {
            let h = cal.component(.hour, from: s.date)
            let days = max(0, cal.dateComponents([.day], from: s.date, to: now).day ?? 0)
            rawH[h] += 0.5 * exp(-Double(days) / 60.0)
        }
        let maxRaw = rawH.max() ?? 0
        var H = [Double](repeating: 0, count: 24)
        if maxRaw > 0 { for h in 0..<24 { H[h] = rawH[h] / maxRaw } }

        // --- Step 3: blend by history confidence ---
        let n = Double(min(input.incidents.count, 20))
        let conf = n / (n + 8.0)             // 0 → ~0.71
        var base = [Double](repeating: 0, count: 24)
        for h in 0..<24 {
            base[h] = P[h] * (1.0 - 0.5 * conf) + H[h] * (0.5 * conf)
        }

        // --- Step 4: dawn/dusk twilight boost ---
        for offset in -1...1 {
            base[wrap(input.dawnHour + offset)] *= 1.25
            base[wrap(input.duskHour + offset)] *= 1.25
        }

        // --- Step 5: global multipliers (constant across hours) ---
        let setupMult = input.setup.riskMultiplier
        var weakMult = 1.0
        weakMult += 0.12 * Double(input.unresolvedGaps)
        weakMult += 0.10 * Double(input.unresolvedDig)
        weakMult += 0.10 * Double(input.unresolvedMesh)
        weakMult += 0.08 * Double(input.unresolvedLatch)
        if input.hasOpenTopExposed { weakMult += 0.15 }
        let deterrentMult = max(0.7, 1.0 - 0.06 * Double(input.activeDeterrents))
        let fortifyMult = max(0.6, 1.0 - 0.05 * Double(input.completedFixes))
        let globalMult = setupMult * weakMult * deterrentMult * fortifyMult

        let combined = base.map { $0 * globalMult }

        // --- Step 6: normalize to 0…100, keeping shape, scaled by absolute ceiling ---
        let peak = combined.max() ?? 0
        var score = [Double](repeating: 0, count: 24)
        if peak > 0 {
            let ceiling = min(max(peak / expectedMax, 0), 1)
            let heightScale = 0.5 + 0.5 * ceiling
            for h in 0..<24 { score[h] = (combined[h] / peak) * 100.0 * heightScale }
        }

        // --- Step 7: peak detection ---
        let dawnPeak = argmaxInWindow(score, center: input.dawnHour, radius: 2)
        let duskPeak = argmaxInWindow(score, center: input.duskHour, radius: 2)
        var globalPeak = 0
        for h in 0..<24 where score[h] > score[globalPeak] { globalPeak = h }

        let hours: [RiskHour] = (0..<24).map { h in
            RiskHour(id: h, hour: h, score: score[h],
                     isDawnPeak: h == dawnPeak && score[h] > 0,
                     isDuskPeak: h == duskPeak && score[h] > 0)
        }

        return RiskResult(hours: hours, mostDangerousHour: globalPeak,
                          dawnPeakHour: dawnPeak, duskPeakHour: duskPeak)
    }

    static func level(for score: Double) -> RiskLevel {
        if score >= 70 { return .attack }
        if score >= 45 { return .risk }
        if score >= 20 { return .watch }
        return .calm
    }

    // MARK: - Helpers

    private static func wrap(_ h: Int) -> Int { ((h % 24) + 24) % 24 }

    private static func argmaxInWindow(_ arr: [Double], center: Int, radius: Int) -> Int {
        var best = wrap(center)
        var bestVal = arr[best]
        for offset in -radius...radius {
            let h = wrap(center + offset)
            if arr[h] > bestVal { bestVal = arr[h]; best = h }
        }
        return best
    }
}
