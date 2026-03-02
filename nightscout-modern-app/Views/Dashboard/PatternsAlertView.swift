import SwiftUI

struct PatternsAlertView: View {
    @Environment(DashboardStore.self) private var store

    var body: some View {
        if store.patternsLoading {
            loadingView
        } else if store.patterns.isEmpty {
            noPatterns
        } else {
            patternsList
        }
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.1))
                    .frame(height: 60)
            }
        }
    }

    private var noPatterns: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(Color(hex: "#22c55e"))
            Text("Nenhum padrão preocupante detectado no período.")
                .font(.caption)
                .foregroundStyle(Color(hex: "#22c55e"))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#22c55e").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var patternsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#f59e0b"))
                Text("Padrões Detectados")
                    .font(.subheadline.weight(.semibold))
                Text("\(store.patterns.count)")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#f59e0b").opacity(0.15))
                    .foregroundStyle(Color(hex: "#f59e0b"))
                    .clipShape(Capsule())
            }

            // Pattern cards
            ForEach(store.patterns, id: \.type) { pattern in
                patternRow(pattern)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func patternRow(_ pattern: DetectedPattern) -> some View {
        let config = patternConfig(pattern)

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: config.icon)
                .font(.system(size: 16))
                .foregroundStyle(config.color)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(config.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(config.color)

                    Text(pattern.severity)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(config.color.opacity(0.12))
                        .foregroundStyle(config.color)
                        .clipShape(Capsule())
                }

                Text(pattern.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let avg = pattern.averageGlucose {
                    Text("Média: \(Int(avg)) mg/dL")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(config.color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(config.color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private struct PatternUIConfig {
        let icon: String
        let label: String
        let color: Color
    }

    private func patternConfig(_ pattern: DetectedPattern) -> PatternUIConfig {
        let severityColor: Color = {
            switch pattern.severity {
            case "low":    return Color(hex: "#3b82f6")
            case "medium": return Color(hex: "#f59e0b")
            case "high":   return Color(hex: "#ef4444")
            default:       return Color(hex: "#f59e0b")
            }
        }()

        let icon: String
        let label: String
        switch pattern.type {
        case "dawn_phenomenon":
            icon = "sunrise.fill"
            label = "Fenômeno do Amanhecer"
        case "nocturnal_hypoglycemia":
            icon = "moon.fill"
            label = "Hipoglicemia Noturna"
        case "high_variability":
            icon = "bolt.fill"
            label = "Alta Variabilidade"
        case "post_meal_spike":
            icon = "chart.line.uptrend.xyaxis"
            label = "Pico Pós-Refeição"
        default:
            icon = "exclamationmark.triangle.fill"
            label = pattern.type
        }

        return PatternUIConfig(icon: icon, label: label, color: severityColor)
    }
}
