import SwiftUI

enum GlucoseLevel: String, Sendable {
    case veryLow
    case low
    case normal
    case high
    case veryHigh

    var color: Color {
        switch self {
        case .veryLow:  GlucoseColors.veryLow
        case .low:      GlucoseColors.low
        case .normal:   GlucoseColors.inRange
        case .high:     GlucoseColors.high
        case .veryHigh: GlucoseColors.veryHigh
        }
    }

    var backgroundColor: Color {
        color.opacity(0.15)
    }

    var label: String {
        switch self {
        case .veryLow:  "Muito Baixo"
        case .low:      "Baixo"
        case .normal:   "No Alvo"
        case .high:     "Alto"
        case .veryHigh: "Muito Alto"
        }
    }

    var icon: String {
        switch self {
        case .veryLow:  "exclamationmark.triangle.fill"
        case .low:      "arrow.down.circle.fill"
        case .normal:   "checkmark.circle.fill"
        case .high:     "arrow.up.circle.fill"
        case .veryHigh: "exclamationmark.triangle.fill"
        }
    }

    static func classify(_ sgv: Int, thresholds: AlarmThresholds = .default) -> GlucoseLevel {
        if sgv < thresholds.veryLow { return .veryLow }
        if sgv < thresholds.low     { return .low }
        if sgv <= thresholds.high   { return .normal }
        if sgv <= thresholds.veryHigh { return .high }
        return .veryHigh
    }
}
