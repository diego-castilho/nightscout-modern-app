import Foundation

// Port of frontend/src/lib/bolus.ts — NS BWP formula

struct BolusBreakdown: Sendable {
    let projectedBG: Double
    let correctionDose: Double
    let foodDose: Double
    let suggested: Double
    let carbEquivalent: Int
    let tempBasal30min: Int?
    let tempBasal1h: Int?
}

enum BolusCalculator {
    static func calculate(
        currentBG: Double,
        targetLow: Double,
        targetHigh: Double,
        isf: Double,
        icr: Double,
        carbs: Double,
        iob: Double,
        basalRate: Double? = nil
    ) -> BolusBreakdown {
        guard isf > 0, icr > 0 else {
            return BolusBreakdown(
                projectedBG: currentBG.rounded(),
                correctionDose: 0, foodDose: 0, suggested: 0,
                carbEquivalent: 0, tempBasal30min: nil, tempBasal1h: nil
            )
        }

        let projectedBG = currentBG - iob * isf

        let correctionDose: Double
        if projectedBG > targetHigh {
            correctionDose = (projectedBG - targetHigh) / isf
        } else if projectedBG < targetLow {
            correctionDose = (projectedBG - targetLow) / isf
        } else {
            correctionDose = 0
        }

        let foodDose = carbs > 0 ? carbs / icr : 0
        let suggested = foodDose + correctionDose

        let carbEquivalent = suggested < 0
            ? Int(ceil(abs(suggested) * icr))
            : 0

        var tempBasal30min: Int? = nil
        var tempBasal1h: Int? = nil
        if let basalRate, basalRate > 0, correctionDose != 0 {
            tempBasal30min = Int(((basalRate / 2 + correctionDose) / (basalRate / 2) * 100).rounded())
            tempBasal1h = Int(((basalRate + correctionDose) / basalRate * 100).rounded())
        }

        let r = { (n: Double) -> Double in ((n * 100).rounded()) / 100 }

        return BolusBreakdown(
            projectedBG: projectedBG.rounded(),
            correctionDose: r(correctionDose),
            foodDose: r(foodDose),
            suggested: r(suggested),
            carbEquivalent: carbEquivalent,
            tempBasal30min: tempBasal30min,
            tempBasal1h: tempBasal1h
        )
    }
}
