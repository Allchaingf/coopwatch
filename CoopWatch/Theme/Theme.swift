//
//  Theme.swift
//  CoopWatch
//
//  Central design system: a dark "night watch" palette (with daytime light
//  counterparts so the Settings theme switch visibly flips the whole UI),
//  gradients, glow effects, spacing tokens, typography and cached formatters.
//  Every API used here is iOS 14.0 safe.
//

import SwiftUI
import UIKit

// MARK: - Dynamic color helper

extension Color {
    /// A color that adapts to the active interface style. `preferredColorScheme`
    /// (set from Settings) flips these automatically — this is what makes the
    /// theme toggle change the entire app.
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    init(hex: UInt, alpha: Double = 1.0) {
        self = Color(UIColor(hex: hex, alpha: alpha))
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: Double = 1.0) {
        let r = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: CGFloat(alpha))
    }
}

// MARK: - Theme namespace

enum Theme {

    // Backgrounds — dark = night palette from the spec, light = soft daytime.
    static let bgTop      = Color.dynamic(light: 0xF1F4FA, dark: 0x0C111C)
    static let bgBottom   = Color.dynamic(light: 0xDFE6F2, dark: 0x070A12)
    static let surface    = Color.dynamic(light: 0xFFFFFF, dark: 0x18202F)
    static let surfaceAlt = Color.dynamic(light: 0xEEF2F9, dark: 0x131A29)
    static let surfaceHi  = Color.dynamic(light: 0xE3EAF5, dark: 0x212B3D)
    static let stroke     = Color.dynamic(light: 0xCAD6E8, dark: 0x2E3A50)

    // Text
    static let textPrimary   = Color.dynamic(light: 0x18202F, dark: 0xEAF0FA)
    static let textSecondary = Color.dynamic(light: 0x586478, dark: 0xAEB9CC)
    static let textDisabled  = Color.dynamic(light: 0x97A1B3, dark: 0x66708A)
    static let textOnAccent  = Color(hex: 0x0C111C)

    // Brand / accents
    static let alarm       = Color.dynamic(light: 0xEF4444, dark: 0xEF4444) // primary alarm red
    static let alarmDeep   = Color.dynamic(light: 0xDC2626, dark: 0xDC2626)
    static let alarmGlow   = Color(hex: 0xFB7185)
    static let dusk        = Color.dynamic(light: 0xF97316, dark: 0xFB923C) // sunset orange
    static let duskGlow    = Color(hex: 0xFDBA74)
    static let moon        = Color.dynamic(light: 0x3B82F6, dark: 0x93C5FD)

    // Semantic / status
    static let protectedC = Color.dynamic(light: 0x16A34A, dark: 0x22C55E)
    static let calmNight  = Color.dynamic(light: 0x2563EB, dark: 0x3B82F6)
    static let riskC      = Color.dynamic(light: 0xEA8A0C, dark: 0xFB923C)
    static let attackC    = Color.dynamic(light: 0xDC2626, dark: 0xEF4444)

    // Convenience alias used widely as the "accent"
    static var accent: Color { alarm }

    // Gradients
    static var background: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
    }
    static var alarmGradient: LinearGradient {
        LinearGradient(colors: [alarm, alarmDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var duskGradient: LinearGradient {
        LinearGradient(colors: [dusk, alarm], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var safeGradient: LinearGradient {
        LinearGradient(colors: [protectedC, Color(hex: 0x15803D)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Spacing scale
    enum Space {
        static let xs: CGFloat = 6
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 22
        static let xl: CGFloat = 32
    }

    // Corner radii
    enum Radius {
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 22
        static let pill: CGFloat = 100
    }

    // Typography (system fonts with rounded/weighted styling)
    static func title(_ size: CGFloat = 26) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func heading(_ size: CGFloat = 19) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular, design: .rounded) }
    static func mono(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
    static func caption(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium, design: .rounded) }
}

// MARK: - Glow modifiers (alert / dusk / moon glows from the spec)

extension View {
    func alarmGlow(_ radius: CGFloat = 14) -> some View {
        shadow(color: Color(hex: 0xEF4444, alpha: 0.35), radius: radius)
    }
    func duskGlow(_ radius: CGFloat = 14) -> some View {
        shadow(color: Color(hex: 0xFB923C, alpha: 0.28), radius: radius)
    }
    func moonGlow(_ radius: CGFloat = 16) -> some View {
        shadow(color: Color(hex: 0x93C5FD, alpha: 0.25), radius: radius)
    }
    func glow(_ color: Color, radius: CGFloat = 12, opacity: Double = 0.5) -> some View {
        shadow(color: color.opacity(opacity), radius: radius)
    }
}

// MARK: - Formatters (cached; .formatted() is iOS 15+, so we use these everywhere)

enum Formatters {
    static func decimal(_ value: Double, digits: Int = 1) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func percent(_ value: Double) -> String { "\(Int(value.rounded()))%" }

    private static let medium: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    private static let dateTimeF: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()
    private static let shortDay: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    private static let timeF: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    static func date(_ d: Date) -> String { medium.string(from: d) }
    static func dateTime(_ d: Date) -> String { dateTimeF.string(from: d) }
    static func dayMonth(_ d: Date) -> String { shortDay.string(from: d) }
    static func time(_ d: Date) -> String { timeF.string(from: d) }

    /// "07:00" style label from hour + minute.
    static func clock(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
    /// "5 AM", "12 PM", "11 PM" — compact hour label for the risk clock.
    static func hourLabel(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        if h == 0 { return "12 AM" }
        if h == 12 { return "12 PM" }
        if h < 12 { return "\(h) AM" }
        return "\(h - 12) PM"
    }

    static func relativeDays(to date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                   to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days == -1 { return "Yesterday" }
        if days > 0 { return "in \(days)d" }
        return "\(-days)d ago"
    }
}

// MARK: - Keyboard dismissal (no @FocusState on iOS 14)

extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
