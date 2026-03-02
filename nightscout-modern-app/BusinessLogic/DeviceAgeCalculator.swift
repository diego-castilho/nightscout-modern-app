import Foundation

// Port of frontend/src/lib/deviceAge.ts

enum AgeLevel: String, Sendable {
    case ok
    case warn
    case urgent
    case unknown
}

struct DeviceAge: Sendable {
    let hours: Double?
    let level: AgeLevel
    let label: String
    let createdAt: String?
    let notes: String?
}

struct DeviceAges: Sendable {
    let sage: DeviceAge      // Sensor Age
    let cage: DeviceAge      // Cannula Age
    let iage: DeviceAge      // Insulin Age
    let basalPen: DeviceAge
    let rapidPen: DeviceAge

    static let unknown = DeviceAges(
        sage: DeviceAge(hours: nil, level: .unknown, label: "—", createdAt: nil, notes: nil),
        cage: DeviceAge(hours: nil, level: .unknown, label: "—", createdAt: nil, notes: nil),
        iage: DeviceAge(hours: nil, level: .unknown, label: "—", createdAt: nil, notes: nil),
        basalPen: DeviceAge(hours: nil, level: .unknown, label: "—", createdAt: nil, notes: nil),
        rapidPen: DeviceAge(hours: nil, level: .unknown, label: "—", createdAt: nil, notes: nil)
    )
}

enum DeviceAgeCalculator {
    /// Format elapsed hours into human-readable string.
    static func formatAge(totalHours: Double, showHours: Bool = true) -> String {
        if totalHours < 24 { return "\(Int(totalHours))h" }
        let days = Int(totalHours / 24)
        let hours = Int(totalHours.truncatingRemainder(dividingBy: 24))
        if !showHours || hours == 0 { return "\(days)d" }
        return "\(days)d \(hours)h"
    }

    private static func ageLevel(hours: Double, warnH: Double, urgentH: Double) -> AgeLevel {
        if hours >= urgentH { return .urgent }
        if hours >= warnH   { return .warn }
        return .ok
    }

    private static func latestOf(treatments: [Treatment], eventType: String) -> Treatment? {
        treatments
            .filter { $0.eventType == eventType }
            .max(by: { $0.createdAtMs < $1.createdAtMs })
    }

    private static func buildDeviceAge(treatment: Treatment?, warnH: Double, urgentH: Double, showHours: Bool) -> DeviceAge {
        guard let treatment else {
            return DeviceAge(hours: nil, level: .unknown, label: "—", createdAt: nil, notes: nil)
        }
        let hours = (Date().timeIntervalSince1970 * 1000 - treatment.createdAtMs) / 3_600_000
        let level = ageLevel(hours: hours, warnH: warnH, urgentH: urgentH)
        return DeviceAge(
            hours: hours,
            level: level,
            label: formatAge(totalHours: hours, showHours: showHours),
            createdAt: treatment.createdAt,
            notes: treatment.notes
        )
    }

    /// Calculate device ages from treatments.
    static func calculate(treatments: [Treatment], thresholds: DeviceAgeThresholds = .default) -> DeviceAges {
        let sageWarnH = Double(thresholds.sageWarnD) * 24
        let sageUrgH = Double(thresholds.sageUrgentD) * 24
        let penWarnH = Double(thresholds.penWarnD) * 24
        let penUrgentH = Double(thresholds.penUrgentD) * 24

        return DeviceAges(
            sage: buildDeviceAge(
                treatment: latestOf(treatments: treatments, eventType: "Sensor Change"),
                warnH: sageWarnH, urgentH: sageUrgH, showHours: true
            ),
            cage: buildDeviceAge(
                treatment: latestOf(treatments: treatments, eventType: "Site Change"),
                warnH: Double(thresholds.cageWarnH), urgentH: Double(thresholds.cageUrgentH), showHours: true
            ),
            iage: buildDeviceAge(
                treatment: latestOf(treatments: treatments, eventType: "Insulin Change"),
                warnH: penWarnH, urgentH: penUrgentH, showHours: false
            ),
            basalPen: buildDeviceAge(
                treatment: latestOf(treatments: treatments, eventType: "Basal Pen Change"),
                warnH: penWarnH, urgentH: penUrgentH, showHours: false
            ),
            rapidPen: buildDeviceAge(
                treatment: latestOf(treatments: treatments, eventType: "Rapid Pen Change"),
                warnH: penWarnH, urgentH: penUrgentH, showHours: false
            )
        )
    }
}
