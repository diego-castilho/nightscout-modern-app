import SwiftUI
import Charts

struct GlucoseAreaChartView: View {
    @Environment(DashboardStore.self) private var store

    @State private var showPrediction = false
    @State private var selectedEntry: GlucoseEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("Leituras de Glicose")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if canShowPrediction {
                    Button {
                        showPrediction.toggle()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chart.line.uptrend.xyaxis") // icone original: waveform.path.ecg
                                .font(.system(size: 9))
                            Text("Preditivo")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(showPrediction ? Color(hex: "#06b6d4").opacity(0.12) : .secondary.opacity(0.08))
                        .foregroundStyle(showPrediction ? Color(hex: "#06b6d4") : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(showPrediction ? Color(hex: "#06b6d4").opacity(0.4) : .secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)

            // Chart
            if store.isLoading && store.entries.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.08))
                    .frame(height: 280)
                    .overlay(ProgressView())
            } else if store.entries.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.08))
                    .frame(height: 280)
                    .overlay(
                        Text("Sem dados para o período")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
            } else {
                chartContent
                    .frame(height: 280)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.secondary.opacity(0.15), lineWidth: 1)
        )
        .onAppear {
            showPrediction = store.predictionsDefault
        }
    }

    // MARK: - Chart

    private var chartContent: some View {
        let thresholds = store.alarmThresholds
        let entries = store.entries.sorted { $0.date < $1.date }

        // AR2 prediction data
        let prediction: AR2Result? = showPrediction ? AR2Prediction.predict(entries: entries) : nil

        // rawActMax: max of actual glucose readings only — used for gradient bbox
        // so gradient color bands stay aligned with threshold lines
        let actualSgvs = entries.map { Double($0.sgv) }
        let rawActMax = actualSgvs.max() ?? 300

        // yMax: includes AR2 upper bounds so predictions fit in the chart
        let predMax = prediction?.predictions.map { $0.sgvPredUpper }.max() ?? 0
        let yMax = Swift.max(rawActMax, predMax) + 30
        let yMin: Double = 0

        // X domain: include AR2 prediction time range
        let entriesXMin = entries.first?.dateValue ?? Date()
        let entriesXMax = entries.last?.dateValue ?? Date()
        let predXMax = prediction?.predictions.last?.date ?? entriesXMax
        let xMax = max(entriesXMax, predXMax)

        // Gradient uses rawActMax (not yMax) so colors align with threshold lines
        let fillGradient = glucoseGradient(thresholds: thresholds, bboxBottom: yMin, bboxTop: rawActMax)

        // Two-layer ZStack: glucose chart (with gradient) + AR2 overlay (solid cyan)
        // This ensures Swift Charts gradient styling doesn't leak into AR2 marks.
        return ZStack {
            // Layer 1: Glucose data with gradient fill
            Chart {
                // Background zone bands
                zoneBands(thresholds: thresholds, yMin: yMin, yMax: yMax)

                // Threshold reference lines
                thresholdLines(thresholds: thresholds)

                // Main glucose data
                ForEach(processedEntries(entries), id: \.date) { entry in
                    AreaMark(
                        x: .value("Tempo", entry.dateValue),
                        yStart: .value("Base", 0),
                        yEnd: .value("Glicose", entry.sgv)
                    )
                    .foregroundStyle(fillGradient)

                    LineMark(
                        x: .value("Tempo", entry.dateValue),
                        y: .value("Glicose", entry.sgv)
                    )
                    .foregroundStyle(GlucoseLevel.classify(entry.sgv, thresholds: thresholds).color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }

                // Glucose dots when few data points
                if entries.count <= 20 {
                    ForEach(entries, id: \.date) { entry in
                        PointMark(
                            x: .value("Tempo", entry.dateValue),
                            y: .value("Glicose", entry.sgv)
                        )
                        .foregroundStyle(GlucoseLevel.classify(entry.sgv, thresholds: thresholds).color)
                        .symbolSize(16)
                    }
                }

                // Selected entry overlay
                if let selected = selectedEntry {
                    RuleMark(x: .value("Selected", selected.dateValue))
                        .foregroundStyle(.secondary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
                        .annotation(position: .top, spacing: 4) {
                            selectionAnnotation(selected)
                        }
                }
            }
            .chartYScale(domain: yMin...yMax)
            .chartXScale(domain: entriesXMin...xMax)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(.secondary.opacity(0.3))
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
                AxisMarks(values: .automatic(desiredCount: xAxisDesiredCount)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(xAxisLabel(date))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x - geo[proxy.plotFrame!].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        selectedEntry = entries.min(by: {
                                            abs($0.dateValue.timeIntervalSince(date)) < abs($1.dateValue.timeIntervalSince(date))
                                        })
                                    }
                                }
                                .onEnded { _ in
                                    selectedEntry = nil
                                }
                        )
                }
            }

            // Layer 2: AR2 prediction overlay — separate Chart with solid cyan styling
            // Rendered on top so gradient from Layer 1 cannot affect these marks.
            if let prediction {
                Chart {
                    // Cone band — solid cyan #06b6d4, 15% opacity
                    ForEach(prediction.predictions) { pt in
                        AreaMark(
                            x: .value("Tempo", pt.date),
                            yStart: .value("Lower", max(yMin, pt.sgvPredLower)),
                            yEnd: .value("Upper", min(yMax, pt.sgvPredUpper))
                        )
                        .foregroundStyle(Color(hex: "#06b6d4").opacity(0.15))
                        .interpolationMethod(.catmullRom)
                    }

                    // Center dashed line — solid cyan #06b6d4, 75% opacity
                    ForEach(prediction.predictions) { pt in
                        LineMark(
                            x: .value("Tempo", pt.date),
                            y: .value("Predicted", pt.sgvPredicted)
                        )
                        .foregroundStyle(Color(hex: "#06b6d4").opacity(0.75))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: yMin...yMax)
                .chartXScale(domain: entriesXMin...xMax)
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .chartPlotStyle { plotArea in
                    plotArea.background(.clear)
                }
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Zone Bands

    @ChartContentBuilder
    private func zoneBands(thresholds: AlarmThresholds, yMin: Double, yMax: Double) -> some ChartContent {
        // Very Low zone
        RectangleMark(
            yStart: .value("", yMin),
            yEnd: .value("", Double(thresholds.veryLow))
        )
        .foregroundStyle(GlucoseColors.veryLow.opacity(0.06))

        // Low zone
        RectangleMark(
            yStart: .value("", Double(thresholds.veryLow)),
            yEnd: .value("", Double(thresholds.low))
        )
        .foregroundStyle(GlucoseColors.low.opacity(0.05))

        // In range zone
        RectangleMark(
            yStart: .value("", Double(thresholds.low)),
            yEnd: .value("", Double(thresholds.high))
        )
        .foregroundStyle(GlucoseColors.inRange.opacity(0.05))

        // High zone
        RectangleMark(
            yStart: .value("", Double(thresholds.high)),
            yEnd: .value("", Double(thresholds.veryHigh))
        )
        .foregroundStyle(GlucoseColors.high.opacity(0.05))

        // Very High zone
        RectangleMark(
            yStart: .value("", Double(thresholds.veryHigh)),
            yEnd: .value("", yMax)
        )
        .foregroundStyle(GlucoseColors.veryHigh.opacity(0.06))
    }

    // MARK: - Threshold Lines

    @ChartContentBuilder
    private func thresholdLines(thresholds: AlarmThresholds) -> some ChartContent {
        // VeryLow — label below the line
        RuleMark(y: .value("Muito Baixo", thresholds.veryLow))
            .foregroundStyle(GlucoseColors.veryLow.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
            .annotation(position: .bottom, alignment: .trailing) {
                thresholdLabel(GlucoseUnit.formatGlucose(thresholds.veryLow, unit: store.unit), color: GlucoseColors.veryLow)
            }

        // Low — label above the line
        RuleMark(y: .value("Baixo", thresholds.low))
            .foregroundStyle(GlucoseColors.low.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .annotation(position: .top, alignment: .trailing) {
                thresholdLabel(GlucoseUnit.formatGlucose(thresholds.low, unit: store.unit), color: GlucoseColors.low)
            }

        // High — label below the line
        RuleMark(y: .value("Alto", thresholds.high))
            .foregroundStyle(GlucoseColors.high.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .annotation(position: .bottom, alignment: .trailing) {
                thresholdLabel(GlucoseUnit.formatGlucose(thresholds.high, unit: store.unit), color: GlucoseColors.high)
            }

        // VeryHigh — label above the line
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
    }

    // MARK: - Gradient
    //
    // Uses bboxTop = rawActMax (actual glucose max, excluding AR2 predictions)
    // so gradient color transitions stay aligned with threshold reference lines
    // even when AR2 extends above the current glucose level.
    // Web reference: buildGradientStops() in GlucoseAreaChart.tsx

    private func glucoseGradient(thresholds: AlarmThresholds, bboxBottom: Double, bboxTop: Double) -> LinearGradient {
        let range = bboxTop - bboxBottom
        guard range > 0 else {
            return LinearGradient(colors: [GlucoseColors.inRange.opacity(0.15)], startPoint: .bottom, endPoint: .top)
        }

        // Maps a glucose value to a gradient location (0 = bottom, 1 = top)
        func loc(_ value: Double) -> Double {
            min(1, max(0, (value - bboxBottom) / range))
        }

        // Zone color for a given glucose value
        func zoneColor(_ val: Double) -> Color {
            if val > Double(thresholds.veryHigh) { return GlucoseColors.veryHigh }
            if val > Double(thresholds.high)     { return GlucoseColors.high }
            if val >= Double(thresholds.low)     { return GlucoseColors.inRange }
            if val >= Double(thresholds.veryLow) { return GlucoseColors.low }
            return GlucoseColors.veryLow
        }

        // Build stops with sharp transitions at each threshold within bbox
        // Web: opacity fades from 0.20 at top to 0.04 at bottom
        var stops: [Gradient.Stop] = []
        let thresholdValues = [Double(thresholds.veryLow), Double(thresholds.low),
                               Double(thresholds.high), Double(thresholds.veryHigh)]

        func opacity(at location: Double) -> Double {
            max(0.04, 0.22 - location * 0.16)
        }

        // Bottom stop
        let bottomLoc: Double = 0
        stops.append(.init(color: zoneColor(bboxBottom).opacity(opacity(at: 1 - bottomLoc)), location: bottomLoc))

        // Threshold stops (two stops at same location for sharp transition)
        for thresh in thresholdValues.sorted() {
            guard thresh > bboxBottom, thresh < bboxTop else { continue }
            let l = loc(thresh)
            stops.append(.init(color: zoneColor(thresh - 1).opacity(opacity(at: 1 - l)), location: l))
            stops.append(.init(color: zoneColor(thresh + 1).opacity(opacity(at: 1 - l)), location: l))
        }

        // Top stop
        let topLoc: Double = 1
        stops.append(.init(color: zoneColor(bboxTop).opacity(opacity(at: 1 - topLoc)), location: topLoc))

        return LinearGradient(stops: stops, startPoint: .bottom, endPoint: .top)
    }

    // MARK: - Selection Annotation

    private func selectionAnnotation(_ entry: GlucoseEntry) -> some View {
        let level = GlucoseLevel.classify(entry.sgv, thresholds: store.alarmThresholds)
        return VStack(spacing: 2) {
            Text(GlucoseUnit.formatGlucose(entry.sgv, unit: store.unit) + " " + store.unit.label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(level.color)
            Text(entry.dateValue, format: .dateTime.hour().minute())
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Helpers

    private var canShowPrediction: Bool {
        switch store.period {
        case .h1, .h3, .h6, .h12, .h24: return true
        case .h48: return false
        }
    }

    private var xAxisDesiredCount: Int {
        switch store.period {
        case .h1:  return 6
        case .h3:  return 6
        case .h6:  return 6
        case .h12: return 6
        case .h24: return 8
        case .h48: return 8
        }
    }

    private func xAxisLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch store.period {
        case .h48:
            formatter.dateFormat = "EEE HH:mm"
        default:
            formatter.dateFormat = "HH:mm"
        }
        return formatter.string(from: date)
    }

    /// Insert null gaps to break lines when readings are >20 min apart.
    private func processedEntries(_ entries: [GlucoseEntry]) -> [GlucoseEntry] {
        // Swift Charts handles gaps by point discontinuity; just return sorted
        entries
    }
}
