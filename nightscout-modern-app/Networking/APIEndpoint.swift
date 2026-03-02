import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum APIEndpoint {
    // Auth
    case login(password: String)
    case generateToken

    // Glucose
    case glucoseLatest
    case glucoseRange(startDate: String, endDate: String)

    // Analytics
    case analytics(startDate: String, endDate: String, thresholds: AlarmThresholds)
    case detectPatterns(startDate: String, endDate: String)
    case calendarData(startDate: String, endDate: String)
    case distributionStats(startDate: String, endDate: String, thresholds: AlarmThresholds)
    case dailyPatterns(startDate: String, endDate: String)

    // Treatments
    case getTreatments(startDate: String, endDate: String, limit: Int, eventType: String?)
    case createTreatment(body: [String: Any])
    case deleteTreatment(id: String)

    // Settings
    case getSettings
    case saveSettings(body: AppSettings)

    var path: String {
        switch self {
        case .login:                          return "/auth/login"
        case .generateToken:                  return "/auth/generate-token"
        case .glucoseLatest:                  return "/glucose/latest"
        case .glucoseRange:                   return "/glucose/range"
        case .analytics:                      return "/analytics"
        case .detectPatterns:                 return "/analytics/detect"
        case .calendarData:                   return "/analytics/calendar"
        case .distributionStats:              return "/analytics/distribution"
        case .dailyPatterns:                  return "/analytics/patterns"
        case .getTreatments:                  return "/treatments"
        case .createTreatment:                return "/treatments"
        case .deleteTreatment(let id):        return "/treatments/\(id)"
        case .getSettings:                    return "/settings"
        case .saveSettings:                   return "/settings"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login, .generateToken, .createTreatment: return .post
        case .saveSettings:                             return .put
        case .deleteTreatment:                          return .delete
        default:                                        return .get
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .glucoseRange(let start, let end):
            return [
                URLQueryItem(name: "startDate", value: start),
                URLQueryItem(name: "endDate", value: end),
            ]

        case .analytics(let start, let end, let t):
            return [
                URLQueryItem(name: "startDate", value: start),
                URLQueryItem(name: "endDate", value: end),
                URLQueryItem(name: "veryLow", value: "\(t.veryLow)"),
                URLQueryItem(name: "low", value: "\(t.low)"),
                URLQueryItem(name: "high", value: "\(t.high)"),
                URLQueryItem(name: "veryHigh", value: "\(t.veryHigh)"),
            ]

        case .detectPatterns(let start, let end):
            return [
                URLQueryItem(name: "startDate", value: start),
                URLQueryItem(name: "endDate", value: end),
            ]

        case .calendarData(let start, let end):
            return [
                URLQueryItem(name: "startDate", value: start),
                URLQueryItem(name: "endDate", value: end),
            ]

        case .distributionStats(let start, let end, let t):
            return [
                URLQueryItem(name: "startDate", value: start),
                URLQueryItem(name: "endDate", value: end),
                URLQueryItem(name: "veryLow", value: "\(t.veryLow)"),
                URLQueryItem(name: "low", value: "\(t.low)"),
                URLQueryItem(name: "high", value: "\(t.high)"),
                URLQueryItem(name: "veryHigh", value: "\(t.veryHigh)"),
            ]

        case .dailyPatterns(let start, let end):
            return [
                URLQueryItem(name: "startDate", value: start),
                URLQueryItem(name: "endDate", value: end),
            ]

        case .getTreatments(let start, let end, let limit, let eventType):
            var items = [
                URLQueryItem(name: "startDate", value: start),
                URLQueryItem(name: "endDate", value: end),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
            if let et = eventType {
                items.append(URLQueryItem(name: "eventType", value: et))
            }
            return items

        default:
            return nil
        }
    }

    var body: Data? {
        switch self {
        case .login(let password):
            return try? JSONSerialization.data(withJSONObject: ["password": password])

        case .createTreatment(let body):
            return try? JSONSerialization.data(withJSONObject: body)

        case .saveSettings(let settings):
            return try? JSONEncoder().encode(settings)

        default:
            return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login: return false
        default:     return true
        }
    }
}
