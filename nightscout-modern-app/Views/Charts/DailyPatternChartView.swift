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
                // Background zone bands (matching glucose chart)
                zoneBands(thresholds: thresholds, yMax: yMax)

                // Threshold reference lines with labels
                thresholdLines(thresholds: thresholds)

                // P5–P95 outer band (light blue)
                ForEach(patterns, id: \.hour) { pattern in
                    AreaMark(
                        x: .value("Hora", pattern.hour),
                        yStart: .value("P5", resolveP5(pattern)),
                        yEnd: .value("P95", resolveP95(pattern))
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.12))
                    .interpolationMethod(.catmullRom)
                }

                // P25–P75 inner band (medium blue)
                ForEach(patterns, id: \.hour) { pattern in
                    AreaMark(
                        x: .value("Hora", pattern.hour),
                        yStart: .value("P25", resolveP25(pattern)),
                        yEnd: .value("P75", resolveP75(pattern))
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.30))
                    .interpolationMethod(.catmullRom)
                }

                // P25 border line
                ForEach(patterns, id: \.hour) { pattern in
                    LineMark(
                        x: .value("Hora", pattern.hour),
                        y: .value("P25Line", resolveP25(pattern))
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.50))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.catmullRom)
                }

                // P75 border line
                ForEach(patterns, id: \.hour) { pattern in
                    LineMark(
                        x: .value("Hora", pattern.hour),
                        y: .value("P75Line", resolveP75(pattern))
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.50))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.catmullRom)
                }

                // P5 border line
                ForEach(patterns, id: \.hour) { pattern in
                    LineMark(
                        x: .value("Hora", pattern.hour),
                        y: .value("P5Line", resolveP5(pattern))
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.28))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.catmullRom)
                }

                // P95 border line
                ForEach(patterns, id: \.hour) { pattern in
                    LineMark(
                        x: .value("Hora", pattern.hour),
                        y: .value("P95Line", resolveP95(pattern))
                    )
                    .foregroundStyle(Color(hex: "#3b82f6").opacity(0.28))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.catmullRom)
                }

                // Median line (P50) — solid blue, thicker
                ForEach(patterns, id: \.hour) { pattern in
                    LineMark(
                        x: .value("Hora", pattern.hour),
                        y: .value("Mediana", pattern.median)
                    )
                    .foregroundStyle(Color(hex: "#3b82f6"))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
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

    // MARK: - Threshold Lines

    @ChartContentBuilder
    private func thresholdLines(thresholds: AlarmThresholds) -> some ChartContent {
        RuleMark(y: .value("Muito Baixo", thresholds.veryLow))
            .foregroundStyle(GlucoseColors.veryLow.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
            .annotation(position: .bottom, alignment: .trailing) {
                thresholdLabel(GlucoseUnit.formatGlucose(thresholds.veryLow, unit: store.unit), color: GlucoseColors.veryLow)
            }

        RuleMark(y: .value("Baixo", thresholds.low))
            .foregroundStyle(GlucoseColors.low.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .annotation(position: .top, alignment: .trailing) {
                thresholdLabel(GlucoseUnit.formatGlucose(thresholds.low, unit: store.unit), color: GlucoseColors.low)
            }

        RuleMark(y: .value("Alto", thresholds.high))
            .foregroundStyle(GlucoseColors.high.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .annotation(position: .bottom, alignment: .trailing) {
                thresholdLabel(GlucoseUnit.formatGlucose(thresholds.high, unit: store.unit), color: GlucoseColors.high)
            }

        RuleMark(y: .value("Muito Alto", thresholds.veryHigh))
            .foregroundStyle(GlucoseColors.veryHigh.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
            .annotation(position: .top, alignment: .trailing) {
                thresholdLabel(GlucoseUnit.formatGlucose(thresholds.veryHigh, unit: store.unit), color: GlucoseColors.veryHigh)
            }
    }

    private func thresholdLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 3)
            .background(.background.opacity(0.8))
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
