import Foundation

enum GlucoseUnit: String, CaseIterable, Identifiable, Sendable, Codable {
    case mgdl = "mgdl"
    case mmol = "mmol"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mgdl: "mg/dL"
        case .mmol: "mmol/L"
        }
    }

    static let mmolFactor = 18.01

    /// Convert mg/dL to the selected display unit.
    static func toDisplayUnit(_ mgdl: Double, unit: GlucoseUnit) -> Double {
        if unit == .mmol {
            return (mgdl / mmolFactor * 10).rounded() / 10
        }
        return mgdl
    }

    /// Convert a value in the selected display unit back to mg/dL.
    static func fromDisplayUnit(_ value: Double, unit: GlucoseUnit) -> Double {
        if unit == .mmol {
            return (value * mmolFactor).rounded()
        }
        return value.rounded()
    }

    /// Format a mg/dL value for display in the selected unit.
    static func formatGlucose(_ mgdl: Double, unit: GlucoseUnit) -> String {
        if unit == .mmol {
            return String(format: "%.1f", mgdl / mmolFactor)
        }
        return "\(Int(mgdl.rounded()))"
    }

    /// Format an Int sgv for display.
    static func formatGlucose(_ sgv: Int, unit: GlucoseUnit) -> String {
        formatGlucose(Double(sgv), unit: unit)
    }
}
