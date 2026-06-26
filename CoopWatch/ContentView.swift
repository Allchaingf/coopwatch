//
//  ContentView.swift
//  CoopWatch
//
//  RootView: the app entry flow state machine — Splash → (first launch only)
//  Onboarding → Main app. No login, welcome, profile or auth of any kind.
//  iOS 14 safe.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var phase: Phase = .splash

    private enum Phase { case splash, onboarding, main }

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashView { advanceFromSplash() }
                    .transition(.opacity)
            case .onboarding:
                OnboardingView {
                    hasCompletedOnboarding = true
                    withAnimation(.easeInOut(duration: 0.4)) { phase = .main }
                }
                .transition(.opacity)
            case .main:
                RootTabView()
                    .transition(.opacity)
            }
        }
    }

    private func advanceFromSplash() {
        withAnimation(.easeInOut(duration: 0.45)) {
            phase = hasCompletedOnboarding ? .main : .onboarding
        }
    }
}
