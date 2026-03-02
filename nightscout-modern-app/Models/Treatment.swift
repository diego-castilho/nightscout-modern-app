import Foundation

struct Treatment: Codable, Identifiable, Sendable {
    let id: String
    let eventType: String
    let createdAt: String
    let timestamp: String?
    let enteredBy: String?
    let glucose: Double?
    let glucoseType: String?
    let carbs: Double?
    let insulin: Double?
    let units: String?
    let notes: String?
    let duration: Double?
    let protein: Double?
    let fat: Double?
    let rate: Double?
    let rateMode: String?
    let exerciseType: String?
    let intensity: String?
    let immediateInsulin: Double?
    let extendedInsulin: Double?
    let preBolus: Double?
    let mealType: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case eventType
        case createdAt = "created_at"
        case timestamp, enteredBy, glucose, glucoseType, carbs, insulin
        case units, notes, duration, protein, fat, rate, rateMode
        case exerciseType, intensity, immediateInsulin, extendedInsulin
        case preBolus, mealType
    }

    var createdAtDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: createdAt) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: createdAt) ?? Date.distantPast
    }

    var createdAtMs: Double {
        createdAtDate.timeIntervalSince1970 * 1000
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // _id can be a string or an ObjectId object { "$oid": "..." }
        if let idStr = try? container.decode(String.self, forKey: .id) {
            id = idStr
        } else if let idObj = try? container.decode([String: String].self, forKey: .id),
                  let oid = idObj["$oid"] {
            id = oid
        } else {
            id = UUID().uuidString
        }

        eventType = try container.decode(String.self, forKey: .eventType)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        enteredBy = try container.decodeIfPresent(String.self, forKey: .enteredBy)
        glucose = try container.decodeIfPresent(Double.self, forKey: .glucose)
        glucoseType = try container.decodeIfPresent(String.self, forKey: .glucoseType)
        carbs = try container.decodeIfPresent(Double.self, forKey: .carbs)
        insulin = try container.decodeIfPresent(Double.self, forKey: .insulin)
        units = try container.decodeIfPresent(String.self, forKey: .units)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        protein = try container.decodeIfPresent(Double.self, forKey: .protein)
        fat = try container.decodeIfPresent(Double.self, forKey: .fat)
        rate = try container.decodeIfPresent(Double.self, forKey: .rate)
        rateMode = try container.decodeIfPresent(String.self, forKey: .rateMode)
        exerciseType = try container.decodeIfPresent(String.self, forKey: .exerciseType)
        intensity = try container.decodeIfPresent(String.self, forKey: .intensity)
        immediateInsulin = try container.decodeIfPresent(Double.self, forKey: .immediateInsulin)
        extendedInsulin = try container.decodeIfPresent(Double.self, forKey: .extendedInsulin)
        preBolus = try container.decodeIfPresent(Double.self, forKey: .preBolus)
        mealType = try container.decodeIfPresent(String.self, forKey: .mealType)
    }
}
