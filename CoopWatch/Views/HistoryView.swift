//
//  HistoryView.swift  (Screen 12 — History)
//  CoopWatch
//
//  One unified, filterable timeline of everything: sightings, attacks, losses
//  and fixed weak points, newest first. iOS 14 safe.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all, attack, sighting, loss, fixed
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    private var entries: [AppStore.TimelineEntry] {
        let all = store.timeline()
        switch filter {
        case .all: return all
        case .attack: return all.filter { $0.kind == .attack }
        case .sighting: return all.filter { $0.kind == .sighting }
        case .loss: return all.filter { $0.kind == .loss }
        case .fixed: return all.filter { $0.kind == .fixed }
        }
    }

    var body: some View {
        ScreenScaffold("History", subtitle: "\(store.timeline().count) events on record", showFence: false) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Filter.allCases) { f in
                        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { filter = f } }) {
                            Text(f.title)
                                .font(Theme.caption(13))
                                .foregroundColor(filter == f ? Theme.textOnAccent : Theme.textPrimary)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Capsule().fill(filter == f ? Theme.alarm : Theme.surface))
                                .overlay(Capsule().stroke(Theme.stroke, lineWidth: filter == f ? 0 : 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 2)
            }

            if entries.isEmpty {
                CardView { EmptyStateView(systemImage: "clock.badge.questionmark", title: "Nothing here",
                                          message: "Events will appear as you log attacks, sightings, losses and fixes.") }
            }

            ForEach(entries) { entry in
                timelineRow(entry)
            }
        }
    }

    private func timelineRow(_ e: AppStore.TimelineEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(e.color.opacity(0.2)).frame(width: 36, height: 36)
                    Image(systemName: e.icon).font(.system(size: 14, weight: .bold)).foregroundColor(e.color)
                }
                Rectangle().fill(Theme.stroke).frame(width: 1.5).frame(maxHeight: .infinity)
            }
            CardView {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(e.title).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text(Formatters.relativeDays(to: e.date)).font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                    }
                    if !e.subtitle.isEmpty {
                        Text(e.subtitle).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                    Text(Formatters.dateTime(e.date)).font(Theme.caption(10)).foregroundColor(Theme.textDisabled)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
