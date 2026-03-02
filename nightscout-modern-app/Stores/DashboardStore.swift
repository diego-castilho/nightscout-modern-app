import Foundation

enum Period: String, CaseIterable, Identifiable, Sendable {
    case h1 = "1h"
    case h3 = "3h"
    case h6 = "6h"
    case h12 = "12h"
    case h24 = "24h"
    case h48 = "48h"

    var id: String { rawValue }
    var label: String { rawValue }

    func dateRange() -> (start: Date, end: Date) {
        let end = Date()
        let start: Date
        switch self {
        case .h1:  start = end.addingTimeInterval(-1 * 3600)
        case .h3:  start = end.addingTimeInterval(-3 * 3600)
        case .h6:  start = end.addingTimeInterval(-6 * 3600)
        case .h12: start = end.addingTimeInterval(-12 * 3600)
        case .h24: start = end.addingTimeInterval(-24 * 3600)
        case .h48: start = end.addingTimeInterval(-48 * 3600)
        }
        return (start, end)
    }

    func isoRange() -> (start: String, end: String) {
        let range = dateRange()
        let formatter = ISO8601DateFormatter()
        return (formatter.string(from: range.start), formatter.string(from: range.end))
    }
}

@Observable
final class DashboardStore {
    // MARK: - Display Settings
    var period: Period = .h24 {
        didSet { UserDefaults.standard.set(period.rawValue, forKey: "period") }
    }
    var unit: GlucoseUnit = .mgdl {
        didSet { UserDefaults.standard.set(unit.rawValue, forKey: "unit") }
    }
    var appTheme: AppTheme = .system {
        didSet { UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme") }
    }
    var patientName: String = ""
    var refreshInterval: Int = 5

    // MARK: - Alarm Thresholds
    var alarmThresholds: AlarmThresholds = .default

    // MARK: - Clinical Parameters
    var dia: Double = 3.0
    var carbAbsorptionRate: Double = 30.0
    var scheduledBasalRate: Double = 0.0
    var isf: Double = 50
    var icr: Double = 15
    var targetBG: Double = 100
    var targetBGHigh: Double = 120
    var rapidPenStep: Double = 1.0
    var predictionsDefault: Bool = false
    var alarmConfig: AlarmConfig = .default
    var deviceAgeThresholds: DeviceAgeThresholds = .default

    // MARK: - Data State
    var entries: [GlucoseEntry] = []
    var latest: GlucoseEntry?
    var analytics: GlucoseAnalytics?
    var treatments: [Treatment] = []
    var isLoading = false
    var error: String?
    var lastRefresh = Date()
    var debugLog: [String] = []

    // MARK: - Computed Values
    var iob: Double = 0
    var cob: Double = 0
    var deviceAges: DeviceAges = .unknown

    // MARK: - Patterns
    var patterns: [DetectedPattern] = []
    var patternsLoading = false

    // MARK: - Timers
    private var refreshTimer: Timer?
    private var iobCobTimer: Timer?

    var apiClient: APIClient?

    init() {
        loadFromUserDefaults()
    }

    // MARK: - Server Settings Sync

    func initFromServer(_ settings: AppSettings) {
        if let unitStr = settings.unit, let u = GlucoseUnit(rawValue: unitStr) { unit = u }
        if let name = settings.patientName { patientName = name }
        if let interval = settings.refreshInterval { refreshInterval = interval }
        if let d = settings.dia { dia = d }
        if let rate = settings.carbAbsorptionRate { carbAbsorptionRate = rate }
        if let t = settings.alarmThresholds { alarmThresholds = t }
        if let rate = settings.scheduledBasalRate { scheduledBasalRate = rate }
        if let s = settings.isf { isf = s }
        if let i = settings.icr { icr = i }
        if let bg = settings.targetBG { targetBG = bg }
        if let bg = settings.targetBGHigh { targetBGHigh = bg }
        if let step = settings.rapidPenStep { rapidPenStep = step }
        if let pred = settings.predictionsDefault { predictionsDefault = pred }
        if let config = settings.alarmConfig { alarmConfig = config }
        if let dat = settings.deviceAgeThresholds { deviceAgeThresholds = dat }
    }

    // MARK: - Data Fetching

    func refreshData() async {
        guard let client = apiClient else { return }

        isLoading = true
        error = nil

        let range = period.isoRange()

        // Analytics always covers at least 24h for clinical meaning
        let analyticsRange: (start: String, end: String)
        switch period {
        case .h1, .h3, .h6, .h12:
            analyticsRange = Period.h24.isoRange()
        default:
            analyticsRange = range
        }

        debugLog.removeAll()
        debugLog.append("Fetching data... period=\(period.rawValue)")

        // Fetch each independently so one failure doesn't block the others
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor [self] in
                do {
                    let result = try await client.getGlucoseRange(startDate: range.start, endDate: range.end)
                    self.entries = result
                    self.debugLog.append("✅ entries: \(result.count)")
                } catch {
                    self.debugLog.append("❌ entries: \(error.localizedDescription)")
                    print("[Dashboard] ❌ entries error: \(error)")
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let result = try await client.getLatestGlucose()
                    self.latest = result
                    self.debugLog.append("✅ latest: sgv=\(result.sgv)")
                } catch {
                    self.debugLog.append("❌ latest: \(error.localizedDescription)")
                    print("[Dashboard] ❌ latest error: \(error)")
                }
            }
            group.addTask { @MainActor [self] in
                do {
                    let result = try await client.getAnalytics(
                        startDate: analyticsRange.start,
                        endDate: analyticsRange.end,
                        thresholds: self.alarmThresholds
                    )
                    self.analytics = result
                    self.debugLog.append("✅ analytics: \(result.totalReadings) readings")
                } catch {
                    self.debugLog.append("❌ analytics: \(error.localizedDescription)")
                    print("[Dashboard] ❌ analytics error: \(error)")
                }
            }
        }

        lastRefresh = Date()
        isLoading = false
    }

    func refreshPatterns() async {
        guard let client = apiClient else { return }

        patternsLoading = true
        let range = period.isoRange()

        do {
            patterns = try await client.detectPatterns(startDate: range.start, endDate: range.end)
        } catch {
            patterns = []
        }
        patternsLoading = false
    }

    func refreshIOBCOB() async {
        guard let client = apiClient else { return }

        let diaMs = dia * 60 * 60 * 1000
        let lookbackMs = max(diaMs, 8 * 60 * 60 * 1000)
        let startDate = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 * 1000 - lookbackMs) / 1000)
        let formatter = ISO8601DateFormatter()

        do {
            let fetchedTreatments = try await client.getTreatments(
                startDate: formatter.string(from: startDate),
                endDate: formatter.string(from: Date()),
                limit: 500
            )
            treatments = fetchedTreatments
            iob = IOBCalculator.calculateIOB(
                treatments: fetchedTreatments,
                diaHours: dia,
                scheduledBasalRate: scheduledBasalRate
            )
            cob = COBCalculator.calculateCOB(
                treatments: fetchedTreatments,
                carbAbsorptionRate: carbAbsorptionRate
            )
        } catch {
            // Silent failure for IOB/COB
        }
    }

    func refreshDeviceAges() async {
        guard let client = apiClient else { return }

        let startDate = Date(timeIntervalSinceNow: -35 * 24 * 3600)
        let formatter = ISO8601DateFormatter()

        do {
            let treatments = try await client.getTreatments(
                startDate: formatter.string(from: startDate),
                endDate: formatter.string(from: Date()),
                limit: 500
            )
            deviceAges = DeviceAgeCalculator.calculate(
                treatments: treatments,
                thresholds: deviceAgeThresholds
            )
        } catch {
            // Keep previous value
        }
    }

    // MARK: - Timer Management

    func startTimers() {
        stopTimers()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: Double(refreshInterval) * 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshData()
            }
        }

        iobCobTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshIOBCOB()
            }
        }
    }

    func stopTimers() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        iobCobTimer?.invalidate()
        iobCobTimer = nil
    }

    // MARK: - Persistence

    private func loadFromUserDefaults() {
        if let periodStr = UserDefaults.standard.string(forKey: "period"),
           let p = Period(rawValue: periodStr) {
            period = p
        }
        if let unitStr = UserDefaults.standard.string(forKey: "unit"),
           let u = GlucoseUnit(rawValue: unitStr) {
            unit = u
        }
        if let themeStr = UserDefaults.standard.string(forKey: "appTheme"),
           let t = AppTheme(rawValue: themeStr) {
            appTheme = t
        }
    }
}
