import SwiftUI
import Charts

struct DailyPatternChartView: View {
    @Environment(DashboardStore.self) private var store

    var body: some View {
        if let analytics = store.analytics, !analytics.dailyPatterns.isEmpty {
            chartContent(analytics)
        }
    }

    private func chartContent(_ analytics: GlucoseAnalytics) -> some View {
        let patterns = analytics.dailyPatterns.sorted { $0.hour < $1.hour }
        let thresholds = store.alarmThresholds
        let ul = store.unit.label

        return VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Padrão Diário (AGP)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(analytics.period.days))d")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Inline stats
            inlineStats(analytics, thresholds: thresholds, ul: ul)

            // Chart
            Chart {
                // Threshold reference lines
                RuleMark(y: .value("Low", thresholds.low))
                    .foregroundStyle(GlucoseColors.low.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
                RuleMark(y: .value("High", thresholds.high))
                    .foregroundStyle(GlucoseColors.high.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [4, 4]))

                ForEach(patterns, id: \.hour) { pattern in
                    let p5 = percentile(pattern, z: 1.645, low: true)
                    let p25 = percentile(pattern, z: 0.674, low: true)
                    let p75 = percentile(pattern, z: 0.674, low: false)
                    let p95 = percentile(pattern, z: 1.645, low: false)

                    // P5-P25 band (outer low)
                    AreaMark(
                        x: .value("Hora", pattern.hour),
                        yStart: .value("P5", p5),
                        yEnd: .value("P25", p25)
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.12))
                    .interpolationMethod(.catmullRom)

                    // P25-P75 band (inner)
                    AreaMark(
                        x: .value("Hora", pattern.hour),
                        yStart: .value("P25", p25),
                        yEnd: .value("P75", p75)
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.30))
                    .interpolationMethod(.catmullRom)

                    // P75-P95 band (outer high)
                    AreaMark(
                        x: .value("Hora", pattern.hour),
                        yStart: .value("P75", p75),
                        yEnd: .value("P95", p95)
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.12))
                    .interpolationMethod(.catmullRom)

                    // Median line
                    LineMark(
                        x: .value("Hora", pattern.hour),
                        y: .value("Mediana", pattern.median)
                    )
                    .foregroundStyle(Color(hex: "#3b82f6"))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: 0...350)
            .chartXScale(domain: 0...23)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(GlucoseUnit.formatGlucose(v, unit: store.unit))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let h = value.as(Int.self) {
                            Text(String(format: "%02d", h))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 240)

            // Legend
            legend
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Inline Stats

    private func inlineStats(_ analytics: GlucoseAnalytics, thresholds: AlarmThresholds, ul: String) -> some View {
        let stats = analytics.stats
        let avgLevel = GlucoseLevel.classify(Int(stats.average), thresholds: thresholds)

        return HStack(spacing: 4) {
            inlineStat(
                label: "Média",
                value: GlucoseUnit.formatGlucose(stats.average, unit: store.unit),
                color: avgLevel.color
            )
            inlineStat(
                label: "GMI",
                value: String(format: "%.1f%%", stats.gmi),
                color: stats.gmi <= 7 ? Color(hex: "#22c55e") : Color(hex: "#f59e0b")
            )
            inlineStat(
                label: "CV%",
                value: String(format: "%.1f%%", stats.cv),
                color: stats.cv <= 36 ? Color(hex: "#22c55e") : Color(hex: "#f59e0b")
            )
            inlineStat(
                label: "No Alvo",
                value: String(format: "%.0f%%", analytics.timeInRange.percentInRange),
                color: analytics.timeInRange.percentInRange >= 70 ? Color(hex: "#22c55e") : Color(hex: "#f59e0b")
            )
        }
    }

    private func inlineStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 12) {
            Spacer()
            legendItem(shape: .line, label: "Mediana (P50)")
            legendItem(shape: .boxDark, label: "P25–P75")
            legendItem(shape: .boxLight, label: "P5–P95")
        }
    }

    private enum LegendShape {
        case line, boxDark, boxLight
    }

    private func legendItem(shape: LegendShape, label: String) -> some View {
        HStack(spacing: 4) {
            switch shape {
            case .line:
                Rectangle()
                    .fill(Color(hex: "#3b82f6"))
                    .frame(width: 16, height: 2)
            case .boxDark:
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hex: "#3b82f6").opacity(0.30))
                    .frame(width: 12, height: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .strokeBorder(Color(hex: "#3b82f6").opacity(0.50), lineWidth: 1)
                    )
            case .boxLight:
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hex: "#3b82f6").opacity(0.12))
                    .frame(width: 12, height: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .strokeBorder(Color(hex: "#3b82f6").opacity(0.28), lineWidth: 1)
                    )
            }

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Percentile Helpers

    private func percentile(_ pattern: DailyPattern, z: Double, low: Bool) -> Double {
        if low {
            if let p = low ? pattern.p5 : pattern.p25, p > 0 { return low && z > 1 ? p : (pattern.p25 ?? max(40, pattern.averageGlucose - pattern.stdDev * z)) }
            return max(40, pattern.averageGlucose - pattern.stdDev * z)
        } else {
            if let p = !low ? pattern.p95 : pattern.p75, p > 0 { return !low && z > 1 ? p : (pattern.p75 ?? min(400, pattern.averageGlucose + pattern.stdDev * z)) }
            return min(400, pattern.averageGlucose + pattern.stdDev * z)
        }
    }
}
