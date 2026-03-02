import Foundation

// Port of AR2 prediction from GlucoseAreaChart.tsx (Nightscout Modern)
struct AR2PredictionPoint: Identifiable {
    let id = UUID()
    let date: Date
    let sgvPredicted: Double
    let sgvPredUpper: Double
    let sgvPredLower: Double
}

struct AR2Result {
    let predictions: [AR2PredictionPoint]
    /// Mean squared log-error of AR2 over last ≤8 readings (model fit quality).
    let avgLoss: Double?
}

enum AR2Prediction {
    private static let bgRef: Double = 140
    private static let bgMin: Double = 36
    private static let bgMax: Double = 400
    private static let arCoef: (Double, Double) = (-0.723, 1.716)
    private static let stepMs: Double = 5 * 60_000
    private static let coneFactor: Double = 2

    // Empirical uncertainty growth per 5-min step (log-space)
    private static let coneSteps: [Double] = [
        0.020, 0.041, 0.061, 0.081, 0.099, 0.116,
        0.132, 0.146, 0.159, 0.171, 0.182, 0.192
    ]

    // Half-width of each 5-min bucket (2.5 min)
    private static let bucketOffsetMs: Double = 2.5 * 60_000
    private static let bucketSizeMs: Double = 5.0 * 60_000

    /// Run AR2 prediction from the latest entries.
    static func predict(entries: [GlucoseEntry], steps: Int = 12) -> AR2Result? {
        guard entries.count >= 2 else { return nil }

        let sorted = entries.sorted { $0.date > $1.date }  // newest first
        let latest = sorted[0]

        // Stale check: no prediction if latest reading is >10 min old
        let nowMs = Date().timeIntervalSince1970 * 1000
        if nowMs - latest.date > 10 * 60_000 { return nil }

        // Compute 5-min buckets around the latest reading
        let (recentBucket, prevBucket) = computeBuckets(entries: entries, latest: latest)
        guard !recentBucket.isEmpty, !prevBucket.isEmpty else { return nil }

        let bgnowMean = bucketMean(recentBucket)
        let mean5MinsAgo = bucketMean(prevBucket)

        guard bgnowMean >= bgMin, mean5MinsAgo >= bgMin else { return nil }

        // avgLoss: mean squared log-error back-tested on last ≤8 valid readings
        let avgLoss = computeAvgLoss(entries: entries)

        // Initialize in log-space
        var prev = log(mean5MinsAgo / bgRef)
        var curr = log(bgnowMean / bgRef)
        var forecastTime = latest.date

        var predictions: [AR2PredictionPoint] = []

        for i in 0..<steps {
            forecastTime += stepMs
            let nextCurr = arCoef.0 * prev + arCoef.1 * curr

            let mgdl = max(bgMin, min(bgMax, (bgRef * exp(nextCurr)).rounded()))
            let cStep = i < coneSteps.count ? coneSteps[i] : coneSteps[coneSteps.count - 1]
            let upper = min(bgMax, (bgRef * exp(nextCurr + coneFactor * cStep)).rounded())
            let lower = max(bgMin, (bgRef * exp(nextCurr - coneFactor * cStep)).rounded())

            let date = Date(timeIntervalSince1970: forecastTime / 1000)
            predictions.append(AR2PredictionPoint(
                date: date,
                sgvPredicted: mgdl,
                sgvPredUpper: upper,
                sgvPredLower: lower
            ))

            prev = curr
            curr = nextCurr
        }

        return AR2Result(predictions: predictions, avgLoss: avgLoss)
    }

    // MARK: - Bucket computation (mirrors glucoseDelta.ts computeBuckets)

    private static func computeBuckets(
        entries: [GlucoseEntry],
        latest: GlucoseEntry
    ) -> (recent: [GlucoseEntry], prev: [GlucoseEntry]) {
        let recent = entries.filter {
            $0.date >= latest.date - bucketOffsetMs && $0.date <= latest.date + bucketOffsetMs
        }
        let prev = entries.filter {
            $0.date >= latest.date - bucketOffsetMs - bucketSizeMs &&
            $0.date < latest.date - bucketOffsetMs
        }
        return (recent, prev)
    }

    private static func bucketMean(_ bucket: [GlucoseEntry]) -> Double {
        bucket.reduce(0.0) { $0 + Double($1.sgv) } / Double(bucket.count)
    }

    // MARK: - Model quality (back-test on last ≤8 readings)

    private static func computeAvgLoss(entries: [GlucoseEntry]) -> Double? {
        let recent = entries
            .filter { Double($0.sgv) >= bgMin }
            .sorted { $0.date < $1.date }
            .suffix(8)

        guard recent.count >= 3 else { return nil }

        let arr = Array(recent)
        var totalLoss = 0.0
        for j in 2..<arr.count {
            let pLog = log(Double(arr[j - 2].sgv) / bgRef)
            let cLog = log(Double(arr[j - 1].sgv) / bgRef)
            let predictedLog = arCoef.0 * pLog + arCoef.1 * cLog
            let actualLog = log(Double(arr[j].sgv) / bgRef)
            totalLoss += pow(predictedLog - actualLog, 2)
        }
        return totalLoss / Double(arr.count - 2)
    }
}
