import Foundation

// Port of frontend/src/lib/cob.ts — Linear absorption model
enum COBCalculator {
    /// Calculate total Carbs on Board from treatments.
    static func calculateCOB(treatments: [Treatment], carbAbsorptionRate: Double) -> Double {
        guard carbAbsorptionRate > 0 else { return 0 }

        let now = Date().timeIntervalSince1970 * 1000

        let total = treatments.reduce(0.0) { sum, t in
            guard let carbs = t.carbs, carbs > 0 else { return sum }

            let elapsed = now - t.createdAtMs
            let absorptionMs = (carbs / carbAbsorptionRate) * 3_600_000

            if elapsed <= 0 || elapsed >= absorptionMs { return sum }

            let fraction = 1 - elapsed / absorptionMs
            return sum + carbs * fraction
        }

        return (total * 10).rounded() / 10
    }
}
