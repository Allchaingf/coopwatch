//
//  Charts.swift
//  CoopWatch
//
//  Hand-drawn charts (Swift Charts is iOS 16+). The flagship radial 24-hour
//  Risk Clock dial, plus line/bar/donut built with Shape/Path/GeometryReader.
//  iOS 14 safe.
//

import SwiftUI

struct ChartDatum: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    var color: Color = Theme.dusk
}

// MARK: - Risk Clock dial (flagship — radial 24-hour attack-risk histogram)

struct RiskClockDial: View {
    let risk: RiskResult
    var dawnHour: Int = 6
    var duskHour: Int = 20
    var size: CGFloat = 280

    private var currentHour: Int { Calendar.current.component(.hour, from: Date()) }
    private var innerRadius: CGFloat { size * 0.30 }
    private var maxBarLen: CGFloat { size / 2 - innerRadius - 10 }

    var body: some View {
        ZStack {
            // outer + inner guide rings
            Circle().stroke(Theme.stroke.opacity(0.6), lineWidth: 1)
            Circle().stroke(Theme.stroke.opacity(0.5), lineWidth: 1)
                .frame(width: innerRadius * 2, height: innerRadius * 2)

            // 24 radial risk bars
            ForEach(risk.hours) { h in
                let len = max(CGFloat(h.score / 100) * maxBarLen, 2)
                Capsule()
                    .fill(barColor(h))
                    .frame(width: barWidth, height: len)
                    .shadow(color: h.score >= 45 ? barColor(h).opacity(0.7) : .clear, radius: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 6)
                    .rotationEffect(.degrees(Double(h.hour) / 24.0 * 360.0))
            }

            // dawn / dusk markers
            marker(systemName: "sunrise.fill", hour: risk.dawnPeakHour, tint: Theme.dusk)
            marker(systemName: "sunset.fill", hour: risk.duskPeakHour, tint: Theme.alarm)

            // current-hour needle
            Rectangle()
                .fill(Theme.moon)
                .frame(width: 2.5, height: size / 2 - 6)
                .shadow(color: Theme.moon.opacity(0.8), radius: 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 4)
                .rotationEffect(.degrees(needleAngle))

            // hour labels at the four cardinal points
            hourLabel("12 AM", angle: 0)
            hourLabel("6 AM", angle: 90)
            hourLabel("12 PM", angle: 180)
            hourLabel("6 PM", angle: 270)

            // center readout
            VStack(spacing: 2) {
                Image(systemName: risk.currentLevel.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(risk.currentLevel.color)
                Text(risk.currentLevel.displayName)
                    .font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Now \(Formatters.hourLabel(currentHour))")
                    .font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
            }
            .frame(width: innerRadius * 1.7)
        }
        .frame(width: size, height: size)
    }

    private var barWidth: CGFloat { max(size * 0.018, 4) }
    private var needleAngle: Double {
        // smooth within-hour position
        let m = Double(Calendar.current.component(.minute, from: Date())) / 60.0
        return (Double(currentHour) + m) / 24.0 * 360.0
    }

    private func barColor(_ h: RiskHour) -> Color {
        if h.score <= 0 { return Theme.surfaceHi }
        return RiskEngine.level(for: h.score).color
    }

    private func hourLabel(_ text: String, angle: Double) -> some View {
        let a = (angle - 90) * .pi / 180
        let r = size / 2 - 2
        return Text(text)
            .font(Theme.caption(9)).foregroundColor(Theme.textSecondary)
            .position(x: size / 2 + cos(a) * r, y: size / 2 + sin(a) * r)
    }

    private func marker(systemName: String, hour: Int, tint: Color) -> some View {
        let a = (Double(hour) / 24.0 * 360.0 - 90) * .pi / 180
        let r = innerRadius - 12
        return Image(systemName: systemName)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(tint)
            .position(x: size / 2 + cos(a) * r, y: size / 2 + sin(a) * r)
    }
}

// MARK: - Bar chart (vertical)

struct BarChartView: View {
    let data: [ChartDatum]
    var height: CGFloat = 160

    private var maxValue: Double { max(data.map { $0.value }.max() ?? 1, 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(data) { d in
                VStack(spacing: 6) {
                    Text(Formatters.decimal(d.value, digits: 0))
                        .font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [d.color, d.color.opacity(0.5)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: max(CGFloat(d.value / maxValue) * height, 3))
                    Text(d.label)
                        .font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height + 36)
    }
}

// MARK: - Line chart

struct LineChartView: View {
    let values: [Double]
    var labels: [String] = []
    var tint: Color = Theme.alarm
    var height: CGFloat = 150

    private var maxValue: Double { max(values.max() ?? 1, 1) }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let step = values.count > 1 ? w / CGFloat(values.count - 1) : w
                ZStack {
                    Path { p in
                        for i in 0...4 {
                            let y = h * CGFloat(i) / 4
                            p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
                        }
                    }
                    .stroke(Theme.stroke.opacity(0.5), lineWidth: 0.5)

                    Path { p in
                        guard !values.isEmpty else { return }
                        p.move(to: CGPoint(x: 0, y: h))
                        for (i, v) in values.enumerated() {
                            p.addLine(to: CGPoint(x: CGFloat(i) * step, y: h - CGFloat(v / maxValue) * h))
                        }
                        p.addLine(to: CGPoint(x: CGFloat(values.count - 1) * step, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))

                    Path { p in
                        guard !values.isEmpty else { return }
                        p.move(to: CGPoint(x: 0, y: h - CGFloat(values[0] / maxValue) * h))
                        for (i, v) in values.enumerated() {
                            p.addLine(to: CGPoint(x: CGFloat(i) * step, y: h - CGFloat(v / maxValue) * h))
                        }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                        Circle().fill(tint)
                            .frame(width: 7, height: 7)
                            .position(x: CGFloat(i) * step, y: h - CGFloat(v / maxValue) * h)
                    }
                }
            }
            .frame(height: height)

            if !labels.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { _, l in
                        Text(l).font(Theme.caption(9)).foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// MARK: - Donut chart

struct DonutChartView: View {
    let data: [ChartDatum]
    var size: CGFloat = 150
    var lineWidth: CGFloat = 26
    var centerLabel: String = "total"

    private var total: Double { max(data.reduce(0) { $0 + $1.value }, 0.0001) }

    var body: some View {
        ZStack {
            ForEach(Array(segments().enumerated()), id: \.offset) { _, seg in
                Circle()
                    .trim(from: seg.start, to: seg.end)
                    .stroke(seg.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text(Formatters.decimal(total, digits: 0))
                    .font(Theme.title(18)).foregroundColor(Theme.textPrimary)
                Text(centerLabel).font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func segments() -> [(start: CGFloat, end: CGFloat, color: Color)] {
        var result: [(CGFloat, CGFloat, Color)] = []
        var running: Double = 0
        for d in data {
            let start = running / total
            running += d.value
            result.append((CGFloat(start), CGFloat(running / total), d.color))
        }
        return result
    }
}

// MARK: - Legend

struct ChartLegend: View {
    let items: [ChartDatum]
    var unit: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                HStack(spacing: 8) {
                    Circle().fill(item.color).frame(width: 9, height: 9)
                    Text(item.label).font(Theme.caption()).foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text("\(Formatters.decimal(item.value, digits: 0))\(unit)")
                        .font(Theme.caption()).foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
}
