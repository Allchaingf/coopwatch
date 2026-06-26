//
//  RiskClockView.swift  (Screen 03 — flagship)
//  CoopWatch
//
//  The 24-hour attack-risk dial. Combines each active predator's diurnal
//  activity with the recency-weighted incident history, then scales by setup,
//  perimeter weaknesses, deterrents and fortifications. Highlights the dawn and
//  dusk peaks and the current hour, and links the logs that feed it.
//  iOS 14 safe.
//

import SwiftUI

struct RiskClockView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                header

                CardView {
                    VStack(spacing: 12) {
                        RiskClockDial(risk: store.risk,
                                      dawnHour: store.coop.dawnHour,
                                      duskHour: store.coop.duskHour,
                                      size: dialSize)
                            .frame(maxWidth: .infinity)
                        legend
                    }
                }

                peaksRow
                threatsCard
                explainerCard

                SectionHeader(title: "What feeds the clock", systemImage: "tablecells")
                NavRow(icon: "exclamationmark.octagon.fill", title: "Attack Log",
                       subtitle: "\(store.incidents.count) incidents", tint: Theme.attackC) { AttackLogView() }
                NavRow(icon: "chart.line.downtrend.xyaxis", title: "Loss Tracker",
                       subtitle: "\(store.totalBirdsLost) birds lost total", tint: Theme.riskC) { LossTrackerView() }
                NavRow(icon: "checklist", title: "Night Routine",
                       subtitle: store.isCoopSecured ? "Locked up" : "\(store.nightRoutineDone)/\(store.nightTasks.count) done",
                       tint: Theme.protectedC) { NightRoutineView() }
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 110)
        }
        .nightScreen(showFence: false)
        .navigationBarHidden(true)
    }

    private var dialSize: CGFloat { min(UIScreen.main.bounds.width - 80, 300) }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Risk Clock").font(Theme.title(27)).foregroundColor(Theme.textPrimary)
                Text("Hourly attack risk by predator & history")
                    .font(Theme.caption()).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            RiskBadge(level: store.currentRiskLevel, compact: true)
        }
        .padding(.top, 4)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendDot(.calm); legendDot(.watch); legendDot(.risk); legendDot(.attack)
        }
    }
    private func legendDot(_ l: RiskLevel) -> some View {
        HStack(spacing: 5) {
            StatusDot(color: l.color, size: 8, glow: false)
            Text(l.displayName).font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
        }
    }

    private var peaksRow: some View {
        HStack(spacing: 12) {
            peakTile(icon: "sunrise.fill", title: "Dawn peak",
                     hour: store.risk.dawnPeakHour, tint: Theme.dusk)
            peakTile(icon: "sunset.fill", title: "Dusk peak",
                     hour: store.risk.duskPeakHour, tint: Theme.alarm)
            peakTile(icon: "exclamationmark.octagon.fill", title: "Most danger",
                     hour: store.mostDangerousHour, tint: Theme.attackC)
        }
    }
    private func peakTile(icon: String, title: String, hour: Int, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(tint)
            Text(Formatters.hourLabel(hour)).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
            Text(title).font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(tint.opacity(0.3), lineWidth: 1))
    }

    private var threatsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Active threats", subtitle: "Tune in Settings", systemImage: "pawprint.fill")
                if store.activeThreats.isEmpty {
                    Text("No threats selected — the clock stays calm. Add predators in Settings to model risk.")
                        .font(Theme.caption()).foregroundColor(Theme.textSecondary)
                } else {
                    FlowChips(items: store.activeThreats.map { ($0.predator.displayName, $0.predator.tint, $0.predator.icon) })
                }
            }
        }
    }

    private var explainerCard: some View {
        CardView {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill").foregroundColor(Theme.dusk)
                Text("Each attack you log nudges its hour higher; the more history, the more the clock trusts your yard over textbook predator behaviour.")
                    .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
            }
        }
    }
}

// MARK: - Simple wrapping chip row

struct FlowChips: View {
    let items: [(String, Color, String)]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 6) {
                    Image(systemName: item.2).font(.system(size: 11)).foregroundColor(item.1)
                    Text(item.0).font(Theme.caption(12)).foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Capsule().fill(item.1.opacity(0.16)))
                .overlay(Capsule().stroke(item.1.opacity(0.35), lineWidth: 1))
            }
        }
    }
}
