//
//  CustomTabBar.swift
//  CoopWatch
//
//  Custom themed tab bar (not the system TabView chrome). Five tabs; the
//  Perimeter tab carries a risk badge. iOS 14 safe.
//

import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case tonight, perimeter, risk, evidence, more
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .tonight: return "Tonight"
        case .perimeter: return "Perimeter"
        case .risk: return "Risk"
        case .evidence: return "Evidence"
        case .more: return "More"
        }
    }
    var icon: String {
        switch self {
        case .tonight: return "moon.stars.fill"
        case .perimeter: return "shield.lefthalf.filled"
        case .risk: return "chart.bar.xaxis"
        case .evidence: return "photo.stack.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selection: AppTab
    var badgeTab: AppTab = .perimeter
    var badge: Int = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { selection = tab }
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Image(systemName: tab.icon)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(selection == tab ? Theme.alarm : Theme.textSecondary)
                                .scaleEffect(selection == tab ? 1.14 : 1.0)
                                .shadow(color: selection == tab ? Theme.alarm.opacity(0.5) : .clear, radius: 6)
                            if tab == badgeTab && badge > 0 {
                                Text("\(badge)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(Theme.attackC))
                                    .offset(x: 13, y: -10)
                            }
                        }
                        Text(tab.title)
                            .font(.system(size: 10, weight: selection == tab ? .bold : .medium, design: .rounded))
                            .foregroundColor(selection == tab ? Theme.alarm : Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .padding(.horizontal, 6)
        .background(
            BlurView(style: .systemThinMaterialDark)
                .overlay(Theme.surface.opacity(0.55))
                .overlay(Rectangle().fill(Theme.stroke).frame(height: 1), alignment: .top)
                .edgesIgnoringSafeArea(.bottom)
        )
    }
}
