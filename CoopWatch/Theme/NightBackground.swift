//
//  NightBackground.swift
//  CoopWatch
//
//  The reusable night backdrop (gradient + stars + moon glow + faint horizon
//  fence) and the thematic shapes used across splash, onboarding and the
//  perimeter map. Drawn entirely with Shapes/Paths — no image assets.
//  iOS 14 safe.
//

import SwiftUI

// MARK: - Coop silhouette (a little hen-house with a pitched roof + door)

struct CoopShape: Shape {
    /// 0 = door fully open, 1 = door fully shut (drawn as a filled panel).
    var doorClosed: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // body
        p.move(to: CGPoint(x: w * 0.12, y: h))
        p.addLine(to: CGPoint(x: w * 0.12, y: h * 0.45))
        p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.14))
        p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.45))
        p.addLine(to: CGPoint(x: w * 0.88, y: h))
        p.addLine(to: CGPoint(x: w * 0.12, y: h))
        // ridge / eave line
        p.move(to: CGPoint(x: w * 0.12, y: h * 0.45))
        p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.45))
        // round entry hole
        let dy = h * 0.62
        let openH = h * 0.38
        p.addRoundedRect(in: CGRect(x: w * 0.40, y: dy, width: w * 0.20, height: openH),
                         cornerSize: CGSize(width: w * 0.10, height: w * 0.10))
        return p
    }
}

/// The door panel that "shuts" over the coop entry (used in the splash exit).
struct CoopDoor: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.addRoundedRect(in: CGRect(x: w * 0.40, y: h * 0.62, width: w * 0.20, height: h * 0.38),
                         cornerSize: CGSize(width: w * 0.10, height: w * 0.10))
        return p
    }
}

// MARK: - Fence (a run of pickets used along the horizon and the map perimeter)

struct FenceShape: Shape {
    var pickets: Int = 14
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let gap = w / CGFloat(pickets)
        // rails
        p.move(to: CGPoint(x: 0, y: h * 0.40)); p.addLine(to: CGPoint(x: w, y: h * 0.40))
        p.move(to: CGPoint(x: 0, y: h * 0.78)); p.addLine(to: CGPoint(x: w, y: h * 0.78))
        // pickets with pointed tops
        var x: CGFloat = gap * 0.4
        while x < w {
            p.move(to: CGPoint(x: x, y: h))
            p.addLine(to: CGPoint(x: x, y: h * 0.18))
            p.addLine(to: CGPoint(x: x + gap * 0.18, y: h * 0.06))
            p.addLine(to: CGPoint(x: x + gap * 0.36, y: h * 0.18))
            p.addLine(to: CGPoint(x: x + gap * 0.36, y: h))
            x += gap
        }
        return p
    }
}

// MARK: - Glowing predator eyes in the dark

struct PredatorEyes: View {
    var color: Color = Theme.alarm
    var glow: Bool = true
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: size * 0.7) {
            eye
            eye
        }
    }
    private var eye: some View {
        Capsule()
            .fill(color)
            .frame(width: size, height: size * 0.66)
            .overlay(
                Capsule().fill(Color.white.opacity(0.85))
                    .frame(width: size * 0.22, height: size * 0.4)
                    .offset(x: size * 0.12)
            )
            .shadow(color: glow ? color.opacity(0.9) : .clear, radius: glow ? size * 0.7 : 0)
    }
}

// MARK: - Moon

struct MoonView: View {
    var size: CGFloat = 54
    var body: some View {
        Circle()
            .fill(Theme.moon)
            .frame(width: size, height: size)
            .overlay(
                Circle().fill(Theme.bgTop)
                    .frame(width: size * 0.82, height: size * 0.82)
                    .offset(x: size * 0.28, y: -size * 0.12)
            )
            .moonGlow(size * 0.45)
    }
}

// MARK: - Star field (static dots placed deterministically)

struct StarField: View {
    var count: Int = 40
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let x = pseudo(i * 2) * geo.size.width
                    let y = pseudo(i * 2 + 1) * geo.size.height * 0.7
                    let s = 1.0 + pseudo(i * 7) * 2.0
                    Circle()
                        .fill(Theme.moon.opacity(0.18 + pseudo(i * 5) * 0.5))
                        .frame(width: s, height: s)
                        .position(x: x, y: y)
                }
            }
        }
        .allowsHitTesting(false)
    }
    /// Deterministic pseudo-random in 0..1 (no Math.random — stable across redraws).
    private func pseudo(_ n: Int) -> CGFloat {
        let v = sin(Double(n) * 12.9898) * 43758.5453
        return CGFloat(v - floor(v))
    }
}

// MARK: - Backdrop view

struct NightBackground: View {
    var showMoon: Bool = true
    var showFence: Bool = true

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background
            StarField(count: 46)

            if showMoon {
                HStack {
                    Spacer()
                    MoonView(size: 60)
                        .padding(.top, 54)
                        .padding(.trailing, 30)
                }
            }

            if showFence {
                VStack {
                    Spacer()
                    FenceShape(pickets: 16)
                        .stroke(Theme.stroke.opacity(0.5),
                                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                        .frame(height: 70)
                        .opacity(0.5)
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Convenience modifier so any screen can sit on the night backdrop.
extension View {
    func nightScreen(showMoon: Bool = true, showFence: Bool = true) -> some View {
        ZStack {
            NightBackground(showMoon: showMoon, showFence: showFence)
            self
        }
    }
}
