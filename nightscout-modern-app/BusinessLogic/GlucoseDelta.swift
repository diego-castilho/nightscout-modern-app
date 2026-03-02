import Foundation

// Port of frontend/src/lib/glucoseDelta.ts — Bucket averaging & delta computation
enum GlucoseDelta {
    private static let bucketOffsetMs: Double = 2.5 * 60_000
    private static let bucketSizeMs: Double = 5.0 * 60_000

    struct Buckets {
        let recent: [GlucoseEntry]
        let prev: [GlucoseEntry]
    }

    /// Compute recent and previous 5-min buckets around the latest entry.
    static func computeBuckets(entries: [GlucoseEntry], latest: GlucoseEntry) -> Buckets {
        let recent = entries.filter {
            $0.date >= latest.date - bucketOffsetMs && $0.date <= latest.date + bucketOffsetMs
        }
        let prev = entries.filter {
            $0.date >= latest.date - bucketOffsetMs - bucketSizeMs &&
            $0.date < latest.date - bucketOffsetMs
        }
        return Buckets(recent: recent, prev: prev)
    }

    /// Calculate delta using Nightscout bucket averaging.
    /// Interpolates to 5-min equivalent when gap > 9 min.
    static func calcNSDelta(latest: GlucoseEntry, entries: [GlucoseEntry]) -> Int? {
        let buckets = computeBuckets(entries: entries, latest: latest)
        guard !buckets.recent.isEmpty, !buckets.prev.isEmpty else { return nil }

        let mean: ([GlucoseEntry]) -> Double = { arr in
            Double(arr.reduce(0) { $0 + $1.sgv }) / Double(arr.count)
        }

        let recentMaxDate = buckets.recent.map(\.date).max() ?? 0
        let prevMaxDate = buckets.prev.map(\.date).max() ?? 0
        let elapsedMins = (recentMaxDate - prevMaxDate) / 60_000
        let absolute = mean(buckets.recent) - mean(buckets.prev)

        if elapsedMins > 9 {
            return Int((absolute / elapsedMins * 5).rounded())
        }
        return Int(absolute.rounded())
    }
}
