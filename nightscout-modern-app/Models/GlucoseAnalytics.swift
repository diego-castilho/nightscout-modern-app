import Foundation

struct GlucoseStats: Codable, Sendable {
    let average: Double
    let median: Double
    let min: Double
    let max: Double
    let stdDev: Double
    let cv: Double
    let gmi: Double
    let estimatedA1c: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        average = try Self.decodeNumber(container, key: .average)
        median = try Self.decodeNumber(container, key: .median)
        min = try Self.decodeNumber(container, key: .min)
        max = try Self.decodeNumber(container, key: .max)
        stdDev = try Self.decodeNumber(container, key: .stdDev)
        cv = try Self.decodeNumber(container, key: .cv)
        gmi = try Self.decodeNumber(container, key: .gmi)
        estimatedA1c = try Self.decodeNumber(container, key: .estimatedA1c)
    }

    private enum CodingKeys: String, CodingKey {
        case average, median, min, max, stdDev, cv, gmi, estimatedA1c
    }

    private static func decodeNumber(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Double {
        if let d = try? container.decode(Double.self, forKey: key) { return d }
        return Double(try container.decode(Int.self, forKey: key))
    }
}

// API returns flat structure: veryLow (count), percentVeryLow (percentage), etc.
struct TimeInRange: Codable, Sendable {
    let veryLow: Int
    let low: Int
    let inRange: Int
    let high: Int
    let veryHigh: Int
    let percentVeryLow: Double
    let percentLow: Double
    let percentInRange: Double
    let percentHigh: Double
    let percentVeryHigh: Double
}

struct DailyPattern: Codable, Sendable {
    let hour: Int
    let averageGlucose: Double
    let median: Double
    let count: Int
    let stdDev: Double
    let min: Double
    let max: Double
    let p5: Double?
    let p25: Double?
    let p75: Double?
    let p95: Double?
}

struct AnalyticsPeriod: Codable, Sendable {
    let start: String
    let end: String
    let days: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try container.decode(String.self, forKey: .start)
        end = try container.decode(String.self, forKey: .end)
        if let d = try? container.decode(Double.self, forKey: .days) {
            days = d
        } else {
            days = Double(try container.decode(Int.self, forKey: .days))
        }
    }

    private enum CodingKeys: String, CodingKey {
        case start, end, days
    }
}

struct GlucoseAnalytics: Codable, Sendable {
    let period: AnalyticsPeriod
    let stats: GlucoseStats
    let timeInRange: TimeInRange
    let dailyPatterns: [DailyPattern]
    let totalReadings: Int
}
