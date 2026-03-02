import SwiftUI

private enum StatStatus {
    case good, warning, bad, neutral

    var color: Color {
        switch self {
        case .good:    Color(hex: "#22c55e")
        case .warning: Color(hex: "#f59e0b")
        case .bad:     Color(hex: "#ef4444")
        case .neutral: .primary
        }
    }
}

struct StatsGridView: View {
    @Environment(DashboardStore.self) private var store

    var body: some View {
        if store.isLoading && store.analytics == nil {
            loadingGrid
        } else if let stats = store.analytics?.stats {
            statsGrid(stats)
        }
    }

    private func statsGrid(_ stats: GlucoseStats) -> some View {
        let ul = store.unit.label
        let avgStatus = averageStatus(stats.average)
        let gmiStat = gmiStatus(stats.gmi)
        let a1cStat = gmiStatus(stats.estimatedA1c)
        let cvStat = cvStatus(stats.cv)

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatCard(
                title: "MÉDIA",
                value: GlucoseUnit.formatGlucose(stats.average, unit: store.unit),
                unit: ul,
                subtitle: "Mediana: \(GlucoseUnit.formatGlucose(stats.median, unit: store.unit)) \(ul)",
                status: avgStatus
            )
            StatCard(
                title: "GMI",
                value: String(format: "%.1f", stats.gmi),
                unit: "%",
                subtitle: "Glucose Management Indicator",
                status: gmiStat
            )
            StatCard(
                title: "A1C EST.",
                value: String(format: "%.1f", stats.estimatedA1c),
                unit: "%",
                subtitle: store.analytics.map { "\(Int($0.period.days))d analisados" },
                status: a1cStat
            )
            StatCard(
                title: "CV%",
                value: String(format: "%.1f", stats.cv),
                unit: "%",
                subtitle: "Alvo < 36% · DP \(GlucoseUnit.formatGlucose(stats.stdDev, unit: store.unit))",
                status: cvStat
            )
        }
    }

    private var loadingGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .frame(height: 90)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.secondary.opacity(0.1))
                    )
            }
        }
    }

    // MARK: - Status helpers

    private func averageStatus(_ avg: Double) -> StatStatus {
        if avg < 54 || avg > 250 { return .bad }
        if avg < 70 || avg > 154 { return .warning }
        return .good
    }

    private func gmiStatus(_ gmi: Double) -> StatStatus {
        if gmi > 8 { return .bad }
        if gmi > 7 { return .warning }
        return .good
    }

    private func cvStatus(_ cv: Double) -> StatStatus {
        if cv > 50 { return .bad }
        if cv > 36 { return .warning }
        return .good
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let subtitle: String?
    let status: StatStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(status.color)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}
