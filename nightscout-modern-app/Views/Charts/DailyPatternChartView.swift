import SwiftUI
import Charts

struct DailyPatternChartView: View {
    @Environment(DashboardStore.self) private var store

    var body: some View {
        if let analytics = store.analytics, !analytics.dailyPatterns.isEmpty {
            chartContent(analytics)
        }
    }

    // MARK: - Processed data point for the chart
    // Mirrors the web's ChartPoint: stacked deltas, not absolute values.

    private struct ChartPoint: Identifiable {
        let id: Int // hour
        let hour: Int
        let median: Double
        let p5: Double
        let p25: Double
        let p75: Double
        let p95: Double
        let count: Int
    }

    private func buildChartPoints(_ patterns: [DailyPattern]) -> [ChartPoint] {
        patterns.sorted { $0.hour < $1.hour }.map { p in
            let p5  = resolveP5(p)
            let p25 = resolveP25(p)
            let p75 = resolveP75(p)
            let p95 = resolveP95(p)
            return ChartPoint(
                id: p.hour,
                hour: p.hour,
                median: p.median,
                p5: p5,
                p25: p25,
                p75: p75,
                p95: p95,
                count: p.count
            )
        }
    }

    private func chartContent(_ analytics: GlucoseAnalytics) -> some View {
        let points = buildChartPoints(analytics.dailyPatterns)
        let thresholds = store.alarmThresholds
        let ul = store.unit.label
        let yMax: Double = 350

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
                // Background zone bands
                zoneBands(thresholds: thresholds, yMax: yMax)

                // Threshold reference lines (no labels, just dashed lines)
                thresholdLines(thresholds: thresholds)

                // P5–P95 outer band (light blue)
                ForEach(points) { pt in
                    AreaMark(
                        x: .value("Hora", pt.hour),
                        yStart: .value("P5", pt.p5),
                        yEnd: .value("P95", pt.p95)
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.12))
                    .interpolationMethod(.monotone)
                }

                // P25–P75 inner band (medium blue)
                ForEach(points) { pt in
                    AreaMark(
                        x: .value("Hora", pt.hour),
                        yStart: .value("P25", pt.p25),
                        yEnd: .value("P75", pt.p75)
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.30))
                    .interpolationMethod(.monotone)
                }

                // P95 border line
                ForEach(points) { pt in
                    LineMark(
                        x: .value("Hora", pt.hour),
                        y: .value("P95Line", pt.p95)
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.28))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.monotone)
                }

                // P75 border line
                ForEach(points) { pt in
                    LineMark(
                        x: .value("Hora", pt.hour),
                        y: .value("P75Line", pt.p75)
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.50))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.monotone)
                }

                // P25 border line
                ForEach(points) { pt in
                    LineMark(
                        x: .value("Hora", pt.hour),
                        y: .value("P25Line", pt.p25)
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.50))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.monotone)
                }

                // P5 border line
                ForEach(points) { pt in
                    LineMark(
                        x: .value("Hora", pt.hour),
                        y: .value("P5Line", pt.p5)
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.28))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.monotone)
                }

                // Median line (P50) — solid blue, thicker
                ForEach(points) { pt in
                    LineMark(
                        x: .value("Hora", pt.hour),
                        y: .value("Mediana", pt.median)
                    )
                    .foregroundStyle(Color(hex: "#3b82f6"))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.monotone)
                }
            }
            .chartYScale(domain: 0...yMax)
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
                            Text(String(format: "%02d:00", h))
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

    // MARK: - Zone Bands

    @ChartContentBuilder
    private func zoneBands(thresholds: AlarmThresholds, yMax: Double) -> some ChartContent {
        RectangleMark(
            yStart: .value("", 0),
            yEnd: .value("", Double(thresholds.veryLow))
        )
        .foregroundStyle(GlucoseColors.veryLow.opacity(0.06))

        RectangleMark(
            yStart: .value("", Double(thresholds.veryLow)),
            yEnd: .value("", Double(thresholds.low))
        )
        .foregroundStyle(GlucoseColors.low.opacity(0.05))

        RectangleMark(
            yStart: .value("", Double(thresholds.low)),
            yEnd: .value("", Double(thresholds.high))
        )
        .foregroundStyle(GlucoseColors.inRange.opacity(0.05))

        RectangleMark(
            yStart: .value("", Double(thresholds.high)),
            yEnd: .value("", Double(thresholds.veryHigh))
        )
        .foregroundStyle(GlucoseColors.high.opacity(0.05))

        RectangleMark(
            yStart: .value("", Double(thresholds.veryHigh)),
            yEnd: .value("", yMax)
        )
        .foregroundStyle(GlucoseColors.veryHigh.opacity(0.06))
    }

    // MARK: - Threshold Lines (no labels, just dashed lines in zone colors)

    @ChartContentBuilder
    private func thresholdLines(thresholds: AlarmThresholds) -> some ChartContent {
        RuleMark(y: .value("", thresholds.veryLow))
            .foregroundStyle(GlucoseColors.veryLow.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))

        RuleMark(y: .value("", thresholds.low))
            .foregroundStyle(GlucoseColors.low.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

        RuleMark(y: .value("", thresholds.high))
            .foregroundStyle(GlucoseColors.high.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

        RuleMark(y: .value("", thresholds.veryHigh))
            .foregroundStyle(GlucoseColors.veryHigh.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
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
    // Uses API values when available; falls back to normal distribution approximation

    private func resolveP5(_ p: DailyPattern) -> Double {
        if let v = p.p5, v > 0 { return v }
        return Swift.max(40, p.averageGlucose - p.stdDev * 1.645)
    }

    private func resolveP25(_ p: DailyPattern) -> Double {
        if let v = p.p25, v > 0 { return v }
        return Swift.max(resolveP5(p), p.averageGlucose - p.stdDev * 0.674)
    }

    private func resolveP75(_ p: DailyPattern) -> Double {
        if let v = p.p75, v > 0 { return v }
        return Swift.min(400, p.averageGlucose + p.stdDev * 0.674)
    }

    private func resolveP95(_ p: DailyPattern) -> Double {
        if let v = p.p95, v > 0 { return v }
        return Swift.min(400, p.averageGlucose + p.stdDev * 1.645)
    }
}
