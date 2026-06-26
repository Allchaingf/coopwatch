//
//  SplashView.swift
//  CoopWatch
//
//  Thematic launch animation. Three+ simultaneously animated layers:
//  (1) night gradient + drifting star shimmer, (2) a coop + fence silhouette
//  with glowing predator eyes that pulse in the dark and then EXTINGUISH as the
//  coop door swings shut (the designed exit), (3) the logo + title spring
//  entrance. A single coordinator timer drives the staged sequence; every
//  looping animation is reset in onDisappear so nothing leaks into the app.
//  iOS 14 safe.
//

import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void

    // Loop teardown guard
    @State private var isVisible = true

    // Staged reveals
    @State private var showStars = false
    @State private var showCoop = false
    @State private var drawCoop: CGFloat = 0
    @State private var showLogo = false
    @State private var exiting = false

    // Looping layers
    @State private var eyesGlow = false
    @State private var shimmer = false

    // Door close (0 = open, 1 = shut) — the designed exit
    @State private var doorShut: CGFloat = 0

    // Single coordinator timer
    @State private var timer: Timer?
    @State private var elapsed: Double = 0

    // Predator eye positions in the dark (normalised within the scene frame)
    private let eyeSpots: [CGPoint] = [
        CGPoint(x: 0.12, y: 0.30), CGPoint(x: 0.86, y: 0.22),
        CGPoint(x: 0.78, y: 0.66), CGPoint(x: 0.20, y: 0.70)
    ]

    var body: some View {
        ZStack {
            // ---- Layer 1: night gradient + star shimmer ----
            Theme.background.ignoresSafeArea()
            StarField(count: 60).opacity(showStars ? 1 : 0)

            LinearGradient(colors: [.clear, Theme.moon.opacity(0.10), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 280)
                .rotationEffect(.degrees(22))
                .offset(x: shimmer ? 320 : -320, y: shimmer ? 180 : -180)
                .ignoresSafeArea()
                .opacity(showStars ? 1 : 0)

            // ---- Layer 2: coop silhouette + glowing eyes ----
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    // glowing predator eyes scattered in the dark
                    ForEach(0..<eyeSpots.count, id: \.self) { i in
                        PredatorEyes(color: i % 2 == 0 ? Theme.alarm : Theme.dusk,
                                     glow: true, size: 16)
                            .scaleEffect(eyesGlow ? 1.0 : 0.82)
                            .opacity(exiting ? 0 : (showCoop ? (eyesGlow ? 1 : 0.55) : 0))
                            .position(x: w * eyeSpots[i].x, y: h * eyeSpots[i].y)
                    }

                    // coop drawing itself in + door shutting
                    ZStack {
                        CoopShape()
                            .trim(from: 0, to: drawCoop)
                            .stroke(Theme.moon, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                            .frame(width: 180, height: 150)
                        // the door panel scales up to seal the entry
                        CoopDoor()
                            .fill(Theme.protectedC)
                            .frame(width: 180, height: 150)
                            .scaleEffect(x: 1, y: doorShut, anchor: .bottom)
                            .opacity(showCoop ? 1 : 0)
                    }
                    .position(x: w * 0.5, y: h * 0.5)
                }
            }
            .frame(height: 300)
            .scaleEffect(exiting ? 1.15 : 1)

            // ---- Layer 3: logo + title ----
            VStack(spacing: 18) {
                ZStack {
                    Circle().stroke(exiting ? Theme.protectedC : Theme.alarm, lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .shadow(color: (exiting ? Theme.protectedC : Theme.alarm).opacity(0.5), radius: 14)
                    // watching eyes turn into a lock once the coop is secured
                    if exiting {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(Theme.protectedC)
                    } else {
                        PredatorEyes(color: Theme.alarm, glow: true, size: 22)
                    }
                }
                .scaleEffect(showLogo ? (exiting ? 1.35 : 1) : 0.4)
                .opacity(showLogo ? 1 : 0)

                VStack(spacing: 6) {
                    Text("COOP WATCH")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .tracking(3)
                    Text("Lock the coop before dusk.")
                        .font(Theme.caption(13))
                        .foregroundColor(Theme.textSecondary)
                }
                .opacity(showLogo ? (exiting ? 0 : 1) : 0)
                .offset(y: showLogo ? 0 : 18)
            }
            .offset(y: 150)
        }
        .onAppear { start() }
        .onDisappear { teardown() }
    }

    // MARK: - Animation control

    private func start() {
        isVisible = true
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { eyesGlow = true }
        withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) { shimmer = true }

        elapsed = 0
        let t = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            elapsed += 0.05
            tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard isVisible else { return }
        if elapsed >= 0.1 && !showStars {
            withAnimation(.easeOut(duration: 0.6)) { showStars = true }
        }
        if elapsed >= 0.6 && !showCoop {
            withAnimation(.easeInOut(duration: 0.4)) { showCoop = true }
            withAnimation(.easeInOut(duration: 1.0)) { drawCoop = 1 }
        }
        if elapsed >= 1.4 && !showLogo {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { showLogo = true }
        }
        if elapsed >= 2.2 && !exiting {
            // designed exit: eyes go dark + door swings shut + logo scales up
            withAnimation(.easeIn(duration: 0.55)) { exiting = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { doorShut = 1 }
        }
        if elapsed >= 2.85 {
            timer?.invalidate(); timer = nil
            onFinish()
        }
    }

    private func teardown() {
        isVisible = false
        timer?.invalidate(); timer = nil
        eyesGlow = false
        shimmer = false
        showStars = false
        showCoop = false
        showLogo = false
        exiting = false
        drawCoop = 0
        doorShut = 0
    }
}
