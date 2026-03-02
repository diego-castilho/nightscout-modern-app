import Foundation

struct GlucoseEntry: Codable, Identifiable, Sendable {
    let id: String
    let sgv: Int
    let date: Double          // milliseconds since epoch
    let dateString: String?
    let trend: Int?
    let direction: String?
    let device: String?
    let type: String?
    let noise: Int?
    let filtered: Double?
    let unfiltered: Double?
    let rssi: Int?
    let delta: Double?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case sgv, date, dateString, trend, direction, device, type
        case noise, filtered, unfiltered, rssi, delta
    }

    var dateValue: Date {
        Date(timeIntervalSince1970: date / 1000)
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

        // sgv can be Int or Double
        if let sgvInt = try? container.decode(Int.self, forKey: .sgv) {
            sgv = sgvInt
        } else {
            sgv = Int(try container.decode(Double.self, forKey: .sgv))
        }

        // date can be Double or Int
        if let dateDouble = try? container.decode(Double.self, forKey: .date) {
            date = dateDouble
        } else {
            date = Double(try container.decode(Int.self, forKey: .date))
        }

        dateString = try container.decodeIfPresent(String.self, forKey: .dateString)
        trend = try container.decodeIfPresent(Int.self, forKey: .trend)
        direction = try container.decodeIfPresent(String.self, forKey: .direction)
        device = try container.decodeIfPresent(String.self, forKey: .device)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        noise = try container.decodeIfPresent(Int.self, forKey: .noise)
        filtered = try container.decodeIfPresent(Double.self, forKey: .filtered)
        unfiltered = try container.decodeIfPresent(Double.self, forKey: .unfiltered)
        rssi = try container.decodeIfPresent(Int.self, forKey: .rssi)
        delta = try container.decodeIfPresent(Double.self, forKey: .delta)
    }
}
