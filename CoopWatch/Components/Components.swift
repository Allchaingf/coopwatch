//
//  Components.swift
//  CoopWatch
//
//  Reusable UI kit: action buttons, cards, chips, stat tiles, status dots,
//  progress, styled inputs, empty state and the screen scaffold. iOS 14 safe
//  (value-form overlay/background, custom ButtonStyles instead of .bordered).
//

import SwiftUI

// MARK: - Button styles

struct ActionButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, safe, danger }
    var kind: Kind = .primary
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.heading(15))
            .foregroundColor(textColor)
            .padding(.vertical, 13)
            .padding(.horizontal, 18)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .stroke(kind == .secondary ? Theme.stroke : Color.clear, lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }

    private var textColor: Color {
        switch kind {
        case .primary: return Theme.textOnAccent
        case .secondary: return Color(hex: 0xE2E8F0)
        case .safe: return Color(hex: 0x06210F)
        case .danger: return Theme.textOnAccent
        }
    }
    @ViewBuilder private var background: some View {
        switch kind {
        case .primary: Theme.alarmGradient
        case .secondary: Theme.surface
        case .safe: Theme.safeGradient
        case .danger: LinearGradient(colors: [Theme.attackC, Theme.alarmDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// Convenience button with optional SF Symbol.
struct ActionButton: View {
    let title: String
    var systemImage: String? = nil
    var kind: ActionButtonStyle.Kind = .primary
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let img = systemImage { Image(systemName: img) }
                Text(title)
            }
        }
        .buttonStyle(ActionButtonStyle(kind: kind, fullWidth: fullWidth))
    }
}

/// A label styled like ActionButton, for use inside NavigationLink.
struct ActionLabel: View {
    let title: String
    var systemImage: String? = nil
    var kind: ActionButtonStyle.Kind = .primary
    var fullWidth: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            if let img = systemImage { Image(systemName: img) }
            Text(title)
        }
        .font(Theme.heading(15))
        .foregroundColor(kind == .secondary ? Color(hex: 0xE2E8F0) : Theme.textOnAccent)
        .padding(.vertical, 13).padding(.horizontal, 18)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .background(kind == .secondary ? AnyView(Theme.surface) : AnyView(Theme.alarmGradient))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m)
            .stroke(kind == .secondary ? Theme.stroke : Color.clear, lineWidth: 1.2))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
    }
}

// MARK: - Card container

struct CardView<Content: View>: View {
    var padding: CGFloat = Theme.Space.m
    var tint: Color? = nil
    let content: () -> Content
    init(padding: CGFloat = Theme.Space.m, tint: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding; self.tint = tint; self.content = content
    }
    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m)
                .stroke(tint ?? Theme.stroke, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let img = systemImage {
                Image(systemName: img).foregroundColor(Theme.dusk)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.heading(17)).foregroundColor(Theme.textPrimary)
                if let s = subtitle {
                    Text(s).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Status chip

struct TagChip: View {
    let text: String
    var color: Color = Theme.dusk
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(Theme.caption(11))
            .foregroundColor(filled ? Theme.textOnAccent : color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(filled ? color : color.opacity(0.18)))
    }
}

// MARK: - Status dot

struct StatusDot: View {
    var color: Color
    var size: CGFloat = 10
    var glow: Bool = true
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: glow ? color.opacity(0.8) : .clear, radius: glow ? size * 0.6 : 0)
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: String
    let label: String
    var systemImage: String
    var tint: Color = Theme.dusk

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(tint)
                Spacer()
            }
            Text(value).font(Theme.title(22)).foregroundColor(Theme.textPrimary)
            Text(label).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                .lineLimit(2)
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(tint.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    var progress: Double           // 0...100
    var size: CGFloat = 64
    var lineWidth: CGFloat = 8
    var tint: Color = Theme.protectedC

    var body: some View {
        ZStack {
            Circle().stroke(Theme.surfaceHi, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 100) / 100))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress.rounded()))%")
                .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Linear progress bar

struct ProgressBar: View {
    var progress: Double           // 0...100
    var tint: Color = Theme.protectedC
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceHi)
                Capsule().fill(tint)
                    .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 100) / 100))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Styled inputs

struct LabeledField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            TextField(placeholder, text: $text)
                .font(Theme.body())
                .foregroundColor(Theme.textPrimary)
                .keyboardType(keyboard)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
        }
    }
}

struct LabeledNumberField: View {
    let label: String
    @Binding var value: Int
    var suffix: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            HStack {
                TextField("0", text: Binding(
                    get: { value == 0 ? "" : "\(value)" },
                    set: { value = Int($0.filter { $0.isNumber }) ?? 0 }
                ))
                .keyboardType(.numberPad)
                .font(Theme.body())
                .foregroundColor(Theme.textPrimary)
                if !suffix.isEmpty { Text(suffix).font(Theme.caption()).foregroundColor(Theme.textSecondary) }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
        }
    }
}

/// A reusable enum picker row that looks consistent across forms.
struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    var systemImage: String = "tray"
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Theme.dusk.opacity(0.8))
            Text(title).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
            Text(message).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: - Risk level badge

struct RiskBadge: View {
    let level: RiskLevel
    var compact: Bool = false
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: level.icon).font(.system(size: compact ? 12 : 14, weight: .bold))
            Text(level.displayName).font(Theme.caption(compact ? 11 : 13))
        }
        .foregroundColor(level.color)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(level.color.opacity(0.16)))
        .overlay(Capsule().stroke(level.color.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Screen scaffold (title + scroll content on night background)

struct ScreenScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var showMoon: Bool = true
    var showFence: Bool = true
    let content: () -> Content

    init(_ title: String, subtitle: String? = nil, showMoon: Bool = true, showFence: Bool = true,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.subtitle = subtitle
        self.showMoon = showMoon; self.showFence = showFence; self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.title(27)).foregroundColor(Theme.textPrimary)
                    if let s = subtitle {
                        Text(s).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(.top, 4)
                content()
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 110)   // clear the custom tab bar
        }
        .nightScreen(showMoon: showMoon, showFence: showFence)
    }
}
