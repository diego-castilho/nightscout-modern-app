import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
    let timestamp: String?
}

struct LoginResponse: Codable, Sendable {
    let token: String
    let expiresIn: String
}

struct DetectedPattern: Codable, Sendable, Identifiable {
    let type: String
    let severity: String
    let description: String
    let averageGlucose: Double?
    let hours: [Int]?

    var id: String { "\(type)-\(severity)" }
}

struct CalendarDayData: Codable, Sendable {
    let date: String
    let readings: Int
    let avgGlucose: Double?
    let minGlucose: Double?
    let maxGlucose: Double?
    let zone: String
    let hypoCount: Int?
    let hypoSevere: Int?
}

struct DistributionStats: Codable, Sendable {
    let totalReadings: Int?
    let histogram: [HistogramBin]
    let gvi: Double?
    let pgs: Double?
    let jIndex: Double?
    let iqr: Double?
    let meanDailyChange: Double?
    let outOfRangeRms: Double?
    let timeInFluctuation: Double?
    let timeInRapidFluctuation: Double?
}

struct HistogramBin: Codable, Sendable {
    let bin: Int
    let count: Int
    let percent: Double
}

