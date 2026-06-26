//
//  OnboardingView.swift
//  CoopWatch
//
//  Four interactive onboarding screens, first launch only. Each has a unique
//  illustrated scene and a DIFFERENT gesture: (1) tap predators → glowing-eyes
//  burst, (2) drag a knob to pick the coop setup, (3) scroll-driven parallax +
//  fence sliders, (4) drag a rotary clock dial to set lock-up time. Choices are
//  persisted into the AppStore. Every looping animation is stopped in
//  onDisappear. iOS 14 safe (PageTabViewStyle, presentationMode, withAnimation).
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    let onComplete: () -> Void

    @State private var page = 0

    // Local working copy, committed to the store on finish.
    @State private var selectedPredators: Set<PredatorType> = []
    @State private var setup: CoopSetup = .openRun
    @State private var fenceLength: Double = 30
    @State private var hasSkirt = false
    @State private var hasTopNet = false
    @State private var lockHour = 19
    @State private var loaded = false

    var body: some View {
        ZStack {
            NightBackground(showMoon: true, showFence: true)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(Theme.caption(14))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, Theme.Space.m)
                        .padding(.top, Theme.Space.m)
                }

                TabView(selection: $page) {
                    ThreatsPage(selected: $selectedPredators).tag(0)
                    SetupPage(setup: $setup).tag(1)
                    PerimeterPage(fenceLength: $fenceLength, hasSkirt: $hasSkirt, hasTopNet: $hasTopNet).tag(2)
                    LockUpPage(hour: $lockHour).tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(i == page ? Theme.alarm : Theme.stroke)
                            .frame(width: i == page ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
                    }
                }
                .padding(.vertical, 12)

                ActionButton(title: primaryTitle,
                             systemImage: page == 3 ? "eye.fill" : "arrow.right") { advance() }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.bottom, Theme.Space.l)
                    .disabled(page == 0 && selectedPredators.isEmpty)
                    .opacity(page == 0 && selectedPredators.isEmpty ? 0.5 : 1)
            }
        }
        .onAppear {
            guard !loaded else { return }
            selectedPredators = Set(store.selectedPredators)
            setup = store.coop.setup
            fenceLength = store.coop.fenceLengthMeters
            hasSkirt = store.coop.hasDigSkirt
            hasTopNet = store.coop.hasTopNet
            lockHour = store.coop.lockUpHour
            loaded = true
        }
    }

    private var primaryTitle: String {
        switch page {
        case 0: return "Set Threats"
        case 1: return "Set Setup"
        case 2: return "Map Perimeter"
        default: return "Start Watch"
        }
    }

    private func advance() {
        if page < 3 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        // Threats
        for p in PredatorType.allCases {
            store.setThreatActive(p, selectedPredators.contains(p))
        }
        // Coop + perimeter + lock-up
        var coop = store.coop
        coop.setup = setup
        coop.fenceLengthMeters = fenceLength
        coop.hasDigSkirt = hasSkirt
        coop.hasTopNet = hasTopNet
        coop.lockUpHour = lockHour
        coop.lockUpMinute = 0
        store.updateCoop(coop)
        onComplete()
    }
}

// MARK: - Page 1: Threats (tap → glowing-eyes burst)

private struct ThreatsPage: View {
    @Binding var selected: Set<PredatorType>
    @State private var bursts: [EyeBurst] = []
    @State private var pulse = false

    struct EyeBurst: Identifiable { let id = UUID(); let origin: CGPoint; let angle: Double; var go = false }

    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            VStack(spacing: 6) {
                Text("Who's hunting your flock?")
                    .font(Theme.title(26)).multilineTextAlignment(.center)
                    .foregroundColor(Theme.textPrimary)
                Text("Tap every threat you've seen — it tunes the risk clock")
                    .font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, Theme.Space.m)

            ZStack {
                MoonView(size: 46).opacity(0.5).scaleEffect(pulse ? 1.05 : 0.95)
            }
            .frame(height: 56)

            ScrollView {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(PredatorType.allCases) { p in
                        predatorCard(p)
                    }
                }
                .padding(.horizontal, Theme.Space.l)
            }
        }
        .overlay(burstOverlay)
        .onAppear { withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true } }
        .onDisappear { pulse = false; bursts.removeAll() }
    }

    private func predatorCard(_ p: PredatorType) -> some View {
        let isOn = selected.contains(p)
        return Button(action: { toggle(p) }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(isOn ? p.tint.opacity(0.22) : Theme.surfaceAlt)
                        .frame(width: 56, height: 56)
                    Image(systemName: p.icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(isOn ? p.tint : Theme.textSecondary)
                    if isOn {
                        PredatorEyes(color: p.tint, glow: true, size: 9)
                            .offset(y: 20)
                    }
                }
                Text(p.displayName).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                Text(p.blurb).font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center).lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m)
                .stroke(isOn ? p.tint : Theme.stroke, lineWidth: isOn ? 1.6 : 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var burstOverlay: some View {
        GeometryReader { _ in
            ZStack {
                ForEach(bursts) { b in
                    Circle()
                        .fill(Theme.alarm)
                        .frame(width: 6, height: 6)
                        .shadow(color: Theme.alarm, radius: 3)
                        .offset(x: b.go ? CGFloat(cos(b.angle)) * 70 : 0,
                                y: b.go ? CGFloat(sin(b.angle)) * 70 : 0)
                        .opacity(b.go ? 0 : 1)
                        .position(b.origin)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func toggle(_ p: PredatorType) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            if selected.contains(p) { selected.remove(p) } else { selected.insert(p) }
        }
        burst()
    }

    private func burst() {
        let origin = CGPoint(x: UIScreen.main.bounds.width / 2, y: 240)
        bursts = (0..<12).map { EyeBurst(origin: origin, angle: Double($0) / 12 * 2 * .pi) }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.6)) { for i in bursts.indices { bursts[i].go = true } }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { bursts.removeAll() }
    }
}

// MARK: - Page 2: Coop Setup (drag knob)

private struct SetupPage: View {
    @Binding var setup: CoopSetup
    private let options = CoopSetup.allCases

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            VStack(spacing: 6) {
                Text("How is your coop set up?")
                    .font(Theme.title(26)).multilineTextAlignment(.center)
                    .foregroundColor(Theme.textPrimary)
                Text("Drag the marker — it sets which points are vulnerable")
                    .font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, Theme.Space.m)

            GeometryReader { geo in
                let trackWidth = geo.size.width - 60
                let segment = options.count > 1 ? trackWidth / CGFloat(options.count - 1) : trackWidth
                let index = options.firstIndex(of: setup) ?? 0
                let knobX = 30 + CGFloat(index) * segment

                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceAlt).frame(height: 10)
                        .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
                    Capsule().fill(Theme.duskGradient).frame(width: knobX, height: 10)
                    Circle()
                        .fill(Theme.alarm)
                        .frame(width: 36, height: 36)
                        .overlay(Image(systemName: setup.icon).foregroundColor(.white).font(.system(size: 15, weight: .bold)))
                        .shadow(color: Theme.alarm.opacity(0.5), radius: 6, y: 3)
                        .position(x: knobX, y: 5)
                        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                            let clamped = min(max(v.location.x - 30, 0), trackWidth)
                            let idx = Int((clamped / segment).rounded())
                            let newSetup = options[min(max(idx, 0), options.count - 1)]
                            if newSetup != setup {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { setup = newSetup }
                            }
                        })
                }
                .frame(height: 40)
                .position(x: geo.size.width / 2, y: 30)
            }
            .frame(height: 60)
            .padding(.horizontal, Theme.Space.l)

            HStack {
                ForEach(options) { o in
                    Text(o.displayName)
                        .font(Theme.caption(12))
                        .fontWeight(setup == o ? .bold : .regular)
                        .foregroundColor(setup == o ? Theme.alarm : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Theme.Space.l)

            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: setup.icon).foregroundColor(Theme.dusk)
                        Text(setup.displayName).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                    }
                    Text(setup.blurb).font(Theme.body()).foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Space.l)
            Spacer()
        }
    }
}

// MARK: - Page 3: Perimeter (scroll-driven parallax + sliders)

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct PerimeterPage: View {
    @Binding var fenceLength: Double
    @Binding var hasSkirt: Bool
    @Binding var hasTopNet: Bool
    @State private var offset: CGFloat = 0

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                // parallax layers
                FenceShape(pickets: 10)
                    .stroke(Theme.stroke.opacity(0.3), lineWidth: 1.4)
                    .frame(width: 200, height: 90)
                    .offset(x: -90, y: -offset * 0.4 + 20)
                MoonView(size: 70).opacity(0.25)
                    .offset(x: 110, y: -offset * 0.25 + 30)

                VStack(spacing: Theme.Space.l) {
                    GeometryReader { proxy in
                        Color.clear.preference(key: ScrollOffsetKey.self,
                                               value: proxy.frame(in: .named("scroll")).minY)
                    }.frame(height: 0)

                    VStack(spacing: 6) {
                        Text("Map your perimeter")
                            .font(Theme.title(26)).multilineTextAlignment(.center)
                            .foregroundColor(Theme.textPrimary)
                            .offset(y: offset * 0.12)
                        Text("Scroll to set the fence and defences we draw on your map")
                            .font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Theme.Space.xl)
                    .padding(.horizontal, Theme.Space.l)

                    // live preview
                    CardView {
                        VStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Theme.moon, lineWidth: 2)
                                    .frame(height: 90)
                                if hasTopNet {
                                    Path { p in
                                        for i in stride(from: 0, through: 8, by: 1) {
                                            let x = CGFloat(i) / 8
                                            p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: 1))
                                        }
                                    }
                                    .stroke(Theme.protectedC.opacity(0.6), lineWidth: 1)
                                    .frame(height: 90)
                                }
                                if hasSkirt {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                        .foregroundColor(Theme.protectedC)
                                        .frame(height: 104)
                                }
                                Image(systemName: "house.fill").foregroundColor(Theme.dusk)
                            }
                            Text("\(Int(fenceLength)) m fence · \(hasSkirt ? "skirt" : "no skirt") · \(hasTopNet ? "top net" : "open top")")
                                .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, Theme.Space.l)

                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("FENCE LENGTH").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text("\(Int(fenceLength)) m").font(Theme.heading(15)).foregroundColor(Theme.dusk)
                                }
                                Slider(value: $fenceLength, in: 5...120, step: 1).accentColor(Theme.alarm)
                            }
                            Toggle(isOn: $hasSkirt) {
                                Label("Dig skirt / apron buried", systemImage: "arrow.down.to.line")
                                    .font(Theme.body()).foregroundColor(Theme.textPrimary)
                            }.toggleStyle(SwitchToggleStyle(tint: Theme.protectedC))
                            Toggle(isOn: $hasTopNet) {
                                Label("Mesh / net over the top", systemImage: "grid")
                                    .font(Theme.body()).foregroundColor(Theme.textPrimary)
                            }.toggleStyle(SwitchToggleStyle(tint: Theme.protectedC))
                        }
                    }
                    .padding(.horizontal, Theme.Space.l)

                    Spacer(minLength: 50)
                }
            }
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetKey.self) { offset = $0 }
    }
}

// MARK: - Page 4: Lock-up (rotary clock dial drag)

private struct LockUpPage: View {
    @Binding var hour: Int
    private let dialSize: CGFloat = 230

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            VStack(spacing: 6) {
                Text("When do you lock up?")
                    .font(Theme.title(26)).multilineTextAlignment(.center)
                    .foregroundColor(Theme.textPrimary)
                Text("Drag the moon around the dial — we'll remind you each evening")
                    .font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, Theme.Space.m)

            ZStack {
                Circle().stroke(Theme.stroke, lineWidth: 1.5)
                Circle().fill(Theme.surface.opacity(0.4))
                // hour ticks
                ForEach(0..<24) { h in
                    Rectangle()
                        .fill(h % 6 == 0 ? Theme.dusk : Theme.stroke)
                        .frame(width: h % 6 == 0 ? 3 : 1.5, height: h % 6 == 0 ? 12 : 7)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 6)
                        .rotationEffect(.degrees(Double(h) / 24 * 360))
                }
                // draggable handle
                handle
                VStack(spacing: 2) {
                    Image(systemName: "lock.fill").foregroundColor(Theme.alarm).font(.system(size: 22, weight: .bold))
                    Text(Formatters.clock(hour: hour, minute: 0))
                        .font(Theme.title(30)).foregroundColor(Theme.textPrimary)
                    Text("lock-up time").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                }
            }
            .frame(width: dialSize, height: dialSize)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                updateHour(from: v.location)
            })

            Spacer()
        }
    }

    private var handle: some View {
        let a = (Double(hour) / 24 * 360 - 90) * .pi / 180
        let r = dialSize / 2 - 18
        return Circle()
            .fill(Theme.moon)
            .frame(width: 30, height: 30)
            .overlay(Image(systemName: "moon.fill").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textOnAccent))
            .shadow(color: Theme.moon.opacity(0.7), radius: 8)
            .position(x: dialSize / 2 + CGFloat(cos(a)) * r,
                      y: dialSize / 2 + CGFloat(sin(a)) * r)
    }

    private func updateHour(from loc: CGPoint) {
        let dx = loc.x - dialSize / 2
        let dy = loc.y - dialSize / 2
        var theta = atan2(Double(dy), Double(dx)) + .pi / 2   // 0 at top, clockwise
        if theta < 0 { theta += 2 * .pi }
        let newHour = Int((theta / (2 * .pi) * 24).rounded()) % 24
        if newHour != hour {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { hour = newHour }
        }
    }
}
