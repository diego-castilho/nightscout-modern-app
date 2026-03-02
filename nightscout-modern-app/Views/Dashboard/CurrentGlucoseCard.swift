import SwiftUI

struct CurrentGlucoseCard: View {
    @Environment(DashboardStore.self) private var store

    var body: some View {
        Group {
            if store.isLoading && store.latest == nil {
                loadingView
            } else if let latest = store.latest {
                glucoseCard(latest)
            } else {
                noDataView
            }
        }
    }

    // MARK: - Main Card

    private func glucoseCard(_ entry: GlucoseEntry) -> some View {
        let level = GlucoseLevel.classify(entry.sgv, thresholds: store.alarmThresholds)

        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // Left: Device ages
                leftColumn()

                Spacer(minLength: 0)

                // Center: Glucose value + badge + IOB/COB
                centerColumn(entry: entry, level: level)

                Spacer(minLength: 0)

                // Right: Trend arrow + description + delta
                rightColumn(entry: entry, level: level)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(level.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(level.color.opacity(0.3), lineWidth: 2)
        )
    }

    // MARK: - Left Column (Device Ages)

    private func leftColumn() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Device age pills
            if store.deviceAges.sage.hours != nil {
                deviceAgePill(icon: "sensor.fill", label: "Sensor", age: store.deviceAges.sage)
            }
            if store.deviceAges.basalPen.hours != nil {
                deviceAgePill(icon: "syringe.fill", label: "Basal", age: store.deviceAges.basalPen)
            }
            if store.deviceAges.rapidPen.hours != nil {
                deviceAgePill(icon: "syringe", label: "Rápida", age: store.deviceAges.rapidPen)
            }

            Spacer(minLength: 0)
        }
        .frame(minWidth: 80, alignment: .leading)
    }

    // MARK: - Center Column (Glucose Value)

    private func centerColumn(entry: GlucoseEntry, level: GlucoseLevel) -> some View {
        let isStale = TimeAgo.isStale(entry.dateValue, minutes: 15)

        return VStack(spacing: 4) {
            // Main glucose value
            Text(GlucoseUnit.formatGlucose(entry.sgv, unit: store.unit))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(level.color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            // Unit label
            Text(store.unit.label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Time ago — centered
            Text(TimeAgo.string(from: entry.dateValue))
                .font(.system(size: 11))
                .foregroundStyle(isStale ? .red : .secondary)

            if isStale {
                Text("DADOS ANTIGOS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.red)
            }

            // Level badge
            Text(level.label)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(level.color.opacity(0.15))
                .foregroundStyle(level.color)
                .clipShape(Capsule())

            // IOB / COB pills
            HStack(spacing: 6) {
                if store.iob >= 0.05 {
                    iobCobPill(
                        label: "IOB",
                        value: String(format: "%.2fU", store.iob),
                        color: Color(hex: "#3b82f6")
                    )
                }
                if store.cob >= 0.5 {
                    iobCobPill(
                        label: "COB",
                        value: String(format: "%.0fg", store.cob),
                        color: Color(hex: "#f97316")
                    )
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Right Column (Trend + Delta)

    private func rightColumn(entry: GlucoseEntry, level: GlucoseLevel) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Trend arrow
            Text(TrendArrow.symbol(for: entry.direction))
                .font(.system(size: 44))
                .foregroundStyle(level.color)

            // Trend description
            Text(TrendArrow.description(for: entry.direction))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            // Delta
            if let delta = computeDelta(entry) {
                Text(formatDelta(delta))
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(level.color)
            }
        }
        .frame(minWidth: 80, alignment: .trailing)
    }

    // MARK: - Sub-views

    private func deviceAgePill(icon: String, label: String, age: DeviceAge) -> some View {
        let pillColor: Color = {
            switch age.level {
            case .ok:      return .secondary
            case .warn:    return Color(hex: "#f59e0b")
            case .urgent:  return .red
            case .unknown: return .secondary
            }
        }()

        return HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text("\(label) \(age.label)")
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(pillColor.opacity(0.12))
        .foregroundStyle(pillColor)
        .clipShape(Capsule())
    }

    private func iobCobPill(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    private var loadingView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .frame(height: 120)
            .overlay(ProgressView())
    }

    private var noDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Sem leitura disponível")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Delta Computation

    private func computeDelta(_ entry: GlucoseEntry) -> Double? {
        // Priority 1: delta from CGM
        if let d = entry.delta { return d }

        // Priority 2: NS bucket averaging
        if let nsDelta = GlucoseDelta.calcNSDelta(latest: entry, entries: store.entries) {
            return Double(nsDelta)
        }

        // Priority 3: simple interpolation from previous entry
        guard let previous = store.entries.last(where: { $0.date < entry.date }) else { return nil }
        let elapsed = (entry.date - previous.date) / 1000 // seconds
        if elapsed > 9 * 60 { return nil }
        let rawDelta = Double(entry.sgv - previous.sgv)
        // Normalize to 5-min rate
        let normalized = rawDelta * (5 * 60) / elapsed
        return normalized
    }

    private func formatDelta(_ delta: Double) -> String {
        let sign = delta >= 0 ? "+" : ""
        if store.unit == .mmol {
            return "\(sign)\(String(format: "%.1f", delta / GlucoseUnit.mmolFactor)) \(store.unit.label)"
        }
        return "\(sign)\(Int(delta.rounded())) \(store.unit.label)"
    }
}
