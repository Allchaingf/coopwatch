//
//  RootTabView.swift
//  CoopWatch
//
//  Main app shell: custom tab bar + per-tab NavigationView stacks. Five tabs —
//  Tonight (dashboard), Perimeter (map + defences), Risk (clock + logs),
//  Evidence (photo gallery) and More (reports, history, reminders, settings).
//  iOS 14 safe (StackNavigationViewStyle).
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var store: AppStore
    @State private var tab: AppTab = .tonight

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .tonight:   stack { TonightDashboardView(switchTab: { tab = $0 }) }
                case .perimeter: stack { PerimeterMapView() }
                case .risk:      stack { RiskClockView() }
                case .evidence:  stack { PhotoEvidenceView() }
                case .more:      stack { MoreHubView() }
                }
            }
            CustomTabBar(selection: $tab, badgeTab: .perimeter, badge: store.riskCount)
        }
        .onAppear { store.resetNightRoutineIfNeeded() }
    }

    private func stack<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        NavigationView { content() }
            .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Reusable navigation row (card style)

struct NavRow<Destination: View>: View {
    let icon: String
    let title: String
    var subtitle: String = ""
    var tint: Color = Theme.dusk
    var badge: Int = 0
    let destination: Destination

    init(icon: String, title: String, subtitle: String = "", tint: Color = Theme.dusk,
         badge: Int = 0, @ViewBuilder destination: () -> Destination) {
        self.icon = icon; self.title = title; self.subtitle = subtitle
        self.tint = tint; self.badge = badge; self.destination = destination()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(tint.opacity(0.18)).frame(width: 42, height: 42)
                    Image(systemName: icon).foregroundColor(tint).font(.system(size: 18, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
                if badge > 0 { TagChip(text: "\(badge)", color: Theme.attackC, filled: true) }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tonight dashboard (Tab 1)

struct TonightDashboardView: View {
    @EnvironmentObject var store: AppStore
    var switchTab: (AppTab) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                header

                riskHeadlineCard

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(value: "\(store.unresolvedWeakPoints.count)", label: "Open weak points",
                             systemImage: "shield.lefthalf.filled", tint: Theme.attackC)
                    StatTile(value: "\(store.birdsLost(inLastDays: 7))", label: "Birds lost (7d)",
                             systemImage: "bird.fill", tint: Theme.riskC)
                    StatTile(value: "\(store.activeDeterrentCount)", label: "Active deterrents",
                             systemImage: "eye.fill", tint: Theme.protectedC)
                    StatTile(value: store.isCoopSecured ? "Locked" : "\(store.nightRoutineDone)/\(store.nightTasks.count)",
                             label: "Night routine", systemImage: "lock.fill",
                             tint: store.isCoopSecured ? Theme.protectedC : Theme.dusk)
                }

                perimeterCard

                SectionHeader(title: "Quick actions", systemImage: "bolt.fill")
                VStack(spacing: 10) {
                    ActionButton(title: "Open perimeter map", systemImage: "map.fill", kind: .secondary) {
                        switchTab(.perimeter)
                    }
                    ActionButton(title: "Log an attack", systemImage: "exclamationmark.octagon.fill", kind: .primary) {
                        switchTab(.risk)
                    }
                    ActionButton(title: "Tonight's lock-up routine", systemImage: "checklist",
                                 kind: store.isCoopSecured ? .safe : .secondary) {
                        switchTab(.risk)
                    }
                }
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 110)
        }
        .nightScreen()
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Coop Watch").font(Theme.title(28)).foregroundColor(Theme.textPrimary)
                Text("Lock up by \(Formatters.clock(hour: store.coop.lockUpHour, minute: store.coop.lockUpMinute))")
                    .font(Theme.caption()).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            MoonView(size: 44)
        }
        .padding(.top, 4)
    }

    private var riskHeadlineCard: some View {
        let level = store.currentRiskLevel
        let peak = store.mostDangerousHour
        return CardView(tint: level.color.opacity(0.5)) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(level.color.opacity(0.18)).frame(width: 64, height: 64)
                    Image(systemName: level.icon).font(.system(size: 26, weight: .bold))
                        .foregroundColor(level.color)
                        .shadow(color: level.color.opacity(0.6), radius: 8)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName).font(Theme.heading(19)).foregroundColor(level.color)
                    Text("Most dangerous hour: \(Formatters.hourLabel(peak))")
                        .font(Theme.caption()).foregroundColor(Theme.textSecondary)
                    Text(store.risk.score(at: peak) > 0 ? "Watch the \(peakWindow) window closely."
                                                       : "Add threats to build your risk clock.")
                        .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var peakWindow: String {
        let peak = store.mostDangerousHour
        if abs(peak - store.coop.dawnHour) <= 2 { return "dawn" }
        if abs(peak - store.coop.duskHour) <= 2 { return "dusk" }
        return "peak"
    }

    private var perimeterCard: some View {
        CardView {
            HStack(spacing: 16) {
                ProgressRing(progress: store.perimeterScore, size: 64, lineWidth: 8,
                             tint: store.perimeterScore > 66 ? Theme.protectedC :
                                   store.perimeterScore > 33 ? Theme.riskC : Theme.attackC)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Perimeter protection").font(Theme.caption()).foregroundColor(Theme.textSecondary)
                    Text(store.unresolvedWeakPoints.isEmpty ? "All points secured"
                         : "\(store.unresolvedWeakPoints.count) point(s) need attention")
                        .font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                    Text("\(store.exposedWeakPoints.count) exposed · \(store.completedFixCount) fixes done")
                        .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
        }
    }
}

// MARK: - More hub (Tab 5)

struct MoreHubView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScreenScaffold("More", subtitle: "Reports, history, reminders & settings", showFence: false) {
            SectionHeader(title: "Insights", systemImage: "chart.bar.fill")
            VStack(spacing: 12) {
                NavRow(icon: "doc.text.fill", title: "Reports",
                       subtitle: "Summaries · export PDF", tint: Theme.alarm) { ReportsView() }
                NavRow(icon: "clock.arrow.circlepath", title: "History",
                       subtitle: "Sightings · attacks · losses · fixes", tint: Theme.dusk) { HistoryView() }
            }

            SectionHeader(title: "Stay alert", systemImage: "bell.badge.fill")
            VStack(spacing: 12) {
                NavRow(icon: "bell.fill", title: "Reminders",
                       subtitle: "Lock-up · perimeter · deterrents", tint: Theme.moon) { RemindersView() }
                NavRow(icon: "list.bullet.clipboard.fill", title: "Night Routine",
                       subtitle: "\(store.nightRoutineDone)/\(store.nightTasks.count) done tonight",
                       tint: Theme.protectedC) { NightRoutineView() }
            }

            SectionHeader(title: "App", systemImage: "gearshape.fill")
            NavRow(icon: "gearshape.fill", title: "Settings",
                   subtitle: "Threats · setup · theme · backup", tint: Theme.textSecondary) { SettingsView() }
        }
        .navigationBarHidden(true)
    }
}
