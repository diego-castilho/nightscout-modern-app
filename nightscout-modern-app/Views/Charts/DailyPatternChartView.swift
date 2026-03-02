import SwiftUI
import Charts

struct DailyPatternChartView: View {
    @Environment(DashboardStore.self) private var store

    /// Analytics always uses at least 24h; only 48h shows a different range.
    private var analyticsLabel: String {
        store.period == .h48 ? "baseado nas últimas 48h" : "baseado nas últimas 24h"
    }

    var body: some View {
        if let analytics = store.analytics, !analytics.dailyPatterns.isEmpty {
            chartContent(analytics)
        }
    }

    // MARK: - Processed data point for the chart

    private struct ChartPoint: Identifiable {
        let id: Int // hour
        let hour: Int
        let median: Double
        let p5: Double
        let p25: Double
        let p75: Double
        let p95: Double
    }

    private func buildChartPoints(_ patterns: [DailyPattern]) -> [ChartPoint] {
        patterns.sorted { $0.hour < $1.hour }.map { p in
            ChartPoint(
                id: p.hour,
                hour: p.hour,
                median: p.median,
                p5: resolveP5(p),
                p25: resolveP25(p),
                p75: resolveP75(p),
                p95: resolveP95(p)
            )
        }
    }

    // MARK: - Row model for AreaMark series
    // Each band (P5-P95, P25-P75) needs a unique series name so Swift Charts
    // connects all its points into one continuous filled shape.

    private struct BandRow: Identifiable {
        let id: String  // "\(band)-\(hour)"
        let hour: Int
        let band: String
        let low: Double
        let high: Double
    }

    private struct LineRow: Identifiable {
        let id: String  // "\(series)-\(hour)"
        let hour: Int
        let series: String
        let value: Double
    }

    private func bandRows(_ points: [ChartPoint]) -> [BandRow] {
        var rows: [BandRow] = []
        for pt in points {
            rows.append(BandRow(id: "outer-\(pt.hour)", hour: pt.hour, band: "outer", low: pt.p5, high: pt.p95))
            rows.append(BandRow(id: "inner-\(pt.hour)", hour: pt.hour, band: "inner", low: pt.p25, high: pt.p75))
        }
        return rows
    }

    private func lineRows(_ points: [ChartPoint]) -> [LineRow] {
        var rows: [LineRow] = []
        for pt in points {
            rows.append(LineRow(id: "p5-\(pt.hour)", hour: pt.hour, series: "p5", value: pt.p5))
            rows.append(LineRow(id: "p25-\(pt.hour)", hour: pt.hour, series: "p25", value: pt.p25))
            rows.append(LineRow(id: "p75-\(pt.hour)", hour: pt.hour, series: "p75", value: pt.p75))
            rows.append(LineRow(id: "p95-\(pt.hour)", hour: pt.hour, series: "p95", value: pt.p95))
            rows.append(LineRow(id: "median-\(pt.hour)", hour: pt.hour, series: "median", value: pt.median))
        }
        return rows
    }

    private func chartContent(_ analytics: GlucoseAnalytics) -> some View {
        let points = buildChartPoints(analytics.dailyPatterns)
        let thresholds = store.alarmThresholds
        let ul = store.unit.label
        let yMax: Double = 350
        let bands = bandRows(points)
        let lines = lineRows(points)

        return VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Padrão Diário (AGP)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(analyticsLabel)
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

                // Percentile area bands — using series to connect all points per band
                ForEach(bands) { row in
                    AreaMark(
                        x: .value("Hora", row.hour),
                        yStart: .value("Low", row.low),
                        yEnd: .value("High", row.high),
                        series: .value("Band", row.band)
                    )
                    .foregroundStyle(row.band == "inner"
                        ? Color(hex: "#3b82f6").opacity(0.30)
                        : Color(hex: "#3b82f6").opacity(0.12))
                    .interpolationMethod(.monotone)
                }

                // Border lines — using series to connect all points per line
                ForEach(lines) { row in
                    if row.series == "median" {
                        LineMark(
                            x: .value("Hora", row.hour),
                            y: .value("Value", row.value),
                            series: .value("Line", row.series)
                        )
                        .foregroundStyle(Color(hex: "#3b82f6"))
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.monotone)
                    } else if row.series == "p25" || row.series == "p75" {
                        LineMark(
                            x: .value("Hora", row.hour),
                            y: .value("Value", row.value),
                            series: .value("Line", row.series)
                        )
                        .foregroundStyle(Color(hex: "#3b82f6").opacity(0.50))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .interpolationMethod(.monotone)
                    } else {
                        LineMark(
                            x: .value("Hora", row.hour),
                            y: .value("Value", row.value),
                            series: .value("Line", row.series)
                        )
                        .foregroundStyle(Color(hex: "#3b82f6").opacity(0.28))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .interpolationMethod(.monotone)
                    }
                }
            }
            .chartYScale(domain: 0...yMax)
            .chartXScale(domain: 0...23)
            .chartLegend(.hidden)
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
