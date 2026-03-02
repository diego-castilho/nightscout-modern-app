import SwiftUI

struct TIRChartView: View {
    @Environment(DashboardStore.self) private var store

    var body: some View {
        if let tir = store.analytics?.timeInRange {
            tirContent(tir)
        }
    }

    private func tirContent(_ tir: TimeInRange) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Tempo no Alvo (TIR)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(store.period.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Stacked horizontal bar
            stackedBar(tir)

            // Targets table
            targetsTable(tir)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Stacked Bar

    private func stackedBar(_ tir: TimeInRange) -> some View {
        let zones: [(pct: Double, color: Color)] = [
            (tir.percentVeryLow, GlucoseColors.veryLow),
            (tir.percentLow, GlucoseColors.low),
            (tir.percentInRange, GlucoseColors.inRange),
            (tir.percentHigh, GlucoseColors.high),
            (tir.percentVeryHigh, GlucoseColors.veryHigh),
        ]

        return GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(zones.indices, id: \.self) { i in
                    let zone = zones[i]
                    if zone.pct >= 0.5 {
                        Rectangle()
                            .fill(zone.color)
                            .frame(width: max(0, geo.size.width * zone.pct / 100))
                            .overlay {
                                if zone.pct >= 6 {
                                    Text(String(format: "%.0f%%", zone.pct))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .shadow(radius: 1)
                                }
                            }
                    }
                }
            }
        }
        .frame(height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Range label formatting

    private func fmtThreshold(_ value: Int) -> String {
        GlucoseUnit.formatGlucose(value, unit: store.unit)
    }

    private func rangeLabel(_ name: String, lowThreshold: Int?, highThreshold: Int?) -> String {
        let ul = store.unit.label
        if let low = lowThreshold, let high = highThreshold {
            return "\(name) - \(fmtThreshold(low))–\(fmtThreshold(high)) \(ul)"
        } else if let high = highThreshold {
            return "\(name) - <\(fmtThreshold(high)) \(ul)"
        } else if let low = lowThreshold {
            return "\(name) - >\(fmtThreshold(low)) \(ul)"
        }
        return name
    }

    // MARK: - Targets Table

    private func targetsTable(_ tir: TimeInRange) -> some View {
        let t = store.alarmThresholds
        let rows: [(label: String, target: String, pct: Double, met: Bool, color: Color)] = [
            (rangeLabel("Muito Baixo", lowThreshold: nil, highThreshold: t.veryLow), "≤ 1%", tir.percentVeryLow, tir.percentVeryLow <= 1, GlucoseColors.veryLow),
            (rangeLabel("Baixo", lowThreshold: t.veryLow, highThreshold: t.low), "≤ 4%", tir.percentLow, tir.percentLow <= 4, GlucoseColors.low),
            (rangeLabel("No Alvo", lowThreshold: t.low, highThreshold: t.high), "≥ 70%", tir.percentInRange, tir.percentInRange >= 70, GlucoseColors.inRange),
            (rangeLabel("Alto", lowThreshold: t.high, highThreshold: t.veryHigh), "≤ 25%", tir.percentHigh, tir.percentHigh <= 25, GlucoseColors.high),
            (rangeLabel("Muito Alto", lowThreshold: t.veryHigh, highThreshold: nil), "≤ 5%", tir.percentVeryHigh, tir.percentVeryHigh <= 5, GlucoseColors.veryHigh),
        ]

        return VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Faixa")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Alvo")
                    .frame(width: 50, alignment: .trailing)
                Text("Real")
                    .frame(width: 50, alignment: .trailing)
                Text("Tempo")
                    .frame(width: 56, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)

            Divider()

            ForEach(rows.indices, id: \.self) { i in
                let row = rows[i]
                HStack(spacing: 4) {
                    // Color swatch + label with range values
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(row.color)
                            .frame(width: 8, height: 8)
                        Text(row.label)
                            .font(.system(size: 11))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Target
                    Text(row.target)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)

                    // Actual %
                    Text(String(format: "%.1f%%", row.pct))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(row.met ? Color(hex: "#22c55e") : Color(hex: "#ef4444"))
                        .frame(width: 50, alignment: .trailing)

                    // Time/day
                    Text(pctToTime(row.pct))
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }
                .padding(.vertical, 4)

                if i < rows.count - 1 {
                    Divider().opacity(0.4)
                }
            }
        }
    }

    private func pctToTime(_ pct: Double) -> String {
        let totalMinutes = pct / 100 * 24 * 60
        let hours = Int(totalMinutes) / 60
        let minutes = Int(totalMinutes) % 60
        return "\(hours)h \(String(format: "%02d", minutes))m"
    }
}
