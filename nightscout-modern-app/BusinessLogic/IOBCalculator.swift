import Foundation

// Port of frontend/src/lib/iob.ts — Walsh bilinear decay model
enum IOBCalculator {
    private static let peakMinutes: Double = 75
    private static let segmentMs: Double = 5 * 60_000

    /// Fraction of bolus still active at elapsedMs after injection.
    static func iobFraction(elapsedMs: Double, diaMs: Double) -> Double {
        if elapsedMs <= 0 || elapsedMs >= diaMs { return 0 }

        let elapsedH = elapsedMs / 3_600_000
        let diaH = diaMs / 3_600_000
        let peakH = peakMinutes / 60

        if diaH <= peakH * 2 {
            return 1 - elapsedH / diaH
        }

        if elapsedH <= peakH {
            return 1 - (elapsedH / diaH) / (2 * (1 - peakH / diaH))
        } else {
            return ((diaH - elapsedH) / (diaH - peakH)) * (peakH / diaH) * 0.5
        }
    }

    /// Temp Basal IOB as sum of 5-min deviation micro-boluses.
    private static func tempBasalIOB(treatments: [Treatment], diaMs: Double, scheduledBasalRate: Double) -> Double {
        let now = Date().timeIntervalSince1970 * 1000
        var total = 0.0

        for t in treatments {
            guard t.eventType == "Temp Basal", let rate = t.rate, let duration = t.duration else { continue }

            let actualRate = t.rateMode == "relative"
                ? (rate / 100) * scheduledBasalRate
                : rate
            let deviation = actualRate - scheduledBasalRate
            if abs(deviation) < 0.001 { continue }

            let startTime = t.createdAtMs
            let endTime = startTime + duration * 60_000
            let deliveredEnd = min(now, endTime)
            if deliveredEnd <= startTime { continue }

            var iob = 0.0
            var seg = startTime
            while seg < deliveredEnd {
                let segEnd = min(seg + segmentMs, deliveredEnd)
                let segMid = (seg + segEnd) / 2
                let segDuration = (segEnd - seg) / 3_600_000
                let segInsulin = deviation * segDuration
                let elapsed = now - segMid
                if elapsed > 0 {
                    iob += segInsulin * iobFraction(elapsedMs: elapsed, diaMs: diaMs)
                }
                seg += segmentMs
            }
            total += iob
        }
        return total
    }

    /// Combo Bolus IOB: immediate + extended components.
    private static func comboBolusIOB(treatments: [Treatment], diaMs: Double) -> Double {
        let now = Date().timeIntervalSince1970 * 1000
        var total = 0.0

        for t in treatments {
            guard t.eventType == "Combo Bolus" else { continue }
            let startTime = t.createdAtMs
            var iob = 0.0

            if let immediate = t.immediateInsulin, immediate > 0 {
                let elapsed = now - startTime
                if elapsed > 0 {
                    iob += immediate * iobFraction(elapsedMs: elapsed, diaMs: diaMs)
                }
            }

            if let extended = t.extendedInsulin, extended > 0, let duration = t.duration, duration > 0 {
                let endTime = startTime + duration * 60_000
                let deliveredEnd = min(now, endTime)
                if deliveredEnd > startTime {
                    var seg = startTime
                    while seg < deliveredEnd {
                        let segEnd = min(seg + segmentMs, deliveredEnd)
                        let segMid = (seg + segEnd) / 2
                        let segDurationMin = (segEnd - seg) / 60_000
                        let segInsulin = extended * (segDurationMin / duration)
                        let elapsed = now - segMid
                        if elapsed > 0 {
                            iob += segInsulin * iobFraction(elapsedMs: elapsed, diaMs: diaMs)
                        }
                        seg += segmentMs
                    }
                }
            }
            total += iob
        }
        return total
    }

    /// Calculate total IOB from treatments.
    static func calculateIOB(treatments: [Treatment], diaHours: Double, scheduledBasalRate: Double = 0) -> Double {
        let now = Date().timeIntervalSince1970 * 1000
        let diaMs = diaHours * 3_600_000

        let bolusIOB = treatments.reduce(0.0) { sum, t in
            if t.eventType == "Basal Insulin" || t.eventType == "Combo Bolus" { return sum }
            guard let insulin = t.insulin, insulin > 0 else { return sum }
            let elapsed = now - t.createdAtMs
            return sum + insulin * iobFraction(elapsedMs: elapsed, diaMs: diaMs)
        }

        let comboIOB = comboBolusIOB(treatments: treatments, diaMs: diaMs)
        let basalIOB = scheduledBasalRate > 0
            ? tempBasalIOB(treatments: treatments, diaMs: diaMs, scheduledBasalRate: scheduledBasalRate)
            : 0

        return (((bolusIOB + comboIOB + basalIOB) * 100).rounded()) / 100
    }
}
