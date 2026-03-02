import Foundation

struct AlarmThresholds: Codable, Sendable, Equatable {
    var veryLow: Int
    var low: Int
    var high: Int
    var veryHigh: Int

    static let `default` = AlarmThresholds(veryLow: 54, low: 70, high: 180, veryHigh: 250)
}

struct AlarmConfig: Codable, Sendable {
    var enabled: Bool
    var veryLow: Bool
    var low: Bool
    var high: Bool
    var veryHigh: Bool
    var predictive: Bool
    var stale: Bool
    var staleMins: Int
    var rapidChange: Bool

    static let `default` = AlarmConfig(
        enabled: true,
        veryLow: true,
        low: true,
        high: true,
        veryHigh: true,
        predictive: true,
        stale: true,
        staleMins: 15,
        rapidChange: true
    )
}

struct DeviceAgeThresholds: Codable, Sendable {
    var sageWarnD: Int      // sensor warning (days)
    var sageUrgentD: Int    // sensor urgent (days)
    var cageWarnH: Int      // cannula warning (hours)
    var cageUrgentH: Int    // cannula urgent (hours)
    var penWarnD: Int       // insulin/pen warning (days)
    var penUrgentD: Int     // insulin/pen urgent (days)

    static let `default` = DeviceAgeThresholds(
        sageWarnD: 10,
        sageUrgentD: 14,
        cageWarnH: 48,
        cageUrgentH: 72,
        penWarnD: 20,
        penUrgentD: 28
    )
}

struct AppSettings: Codable, Sendable {
    var unit: String?
    var patientName: String?
    var refreshInterval: Int?
    var alarmThresholds: AlarmThresholds?
    var dia: Double?
    var carbAbsorptionRate: Double?
    var scheduledBasalRate: Double?
    var isf: Double?
    var icr: Double?
    var targetBG: Double?
    var targetBGHigh: Double?
    var rapidPenStep: Double?
    var predictionsDefault: Bool?
    var alarmConfig: AlarmConfig?
    var deviceAgeThresholds: DeviceAgeThresholds?
}
