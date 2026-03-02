import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(String)
    case decodingError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:             return "URL inválida"
        case .unauthorized:           return "Não autorizado"
        case .serverError(let msg):   return msg
        case .decodingError(let msg): return "Erro de decodificação: \(msg)"
        case .networkError(let msg):  return msg
        }
    }
}

@Observable
final class APIClient: @unchecked Sendable {
    var baseURL: URL

    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
    }

    // MARK: - Generic Request

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        // Build URL by appending path to base, avoiding double-slash issues
        let baseStr = baseURL.absoluteString.hasSuffix("/")
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        let fullURL = baseStr + endpoint.path

        var components = URLComponents(string: fullURL)
        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            print("[API] ❌ Invalid URL for endpoint: \(endpoint.path)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token
        if endpoint.requiresAuth, let token = KeychainService.load(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add body
        if let body = endpoint.body {
            request.httpBody = body
        }

        print("[API] \(endpoint.method.rawValue) \(url.absoluteString)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch {
            print("[API] ❌ Network error: \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Resposta inválida do servidor")
        }

        print("[API] Status: \(httpResponse.statusCode) — \(data.count) bytes")

        if httpResponse.statusCode == 401 {
            KeychainService.delete(forKey: "authToken")
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = (try? decoder.decode(APIResponse<String>.self, from: data))?.error
                ?? "Erro do servidor (\(httpResponse.statusCode))"
            print("[API] ❌ Server error: \(errorMessage)")
            throw APIError.serverError(errorMessage)
        }

        // Try decoding as APIResponse<T> first (wrapped), then as T directly
        if let wrapped = try? decoder.decode(APIResponse<T>.self, from: data), let result = wrapped.data {
            return result
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Print raw JSON for debugging
            let jsonStr = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[API] ❌ Decode error for \(T.self).")
            print("[API] ❌ Raw JSON (first 1000 chars): \(String(jsonStr.prefix(1000)))")
            // Print detailed decode error path
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("[API] ❌ Missing key '\(key.stringValue)' at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                case .typeMismatch(let type, let context):
                    print("[API] ❌ Type mismatch: expected \(type) at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                    print("[API] ❌ Debug description: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("[API] ❌ Value not found: \(type) at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("[API] ❌ Data corrupted at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                @unknown default:
                    print("[API] ❌ Unknown decode error: \(error)")
                }
            }
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Convenience Methods

    func login(password: String) async throws -> LoginResponse {
        try await request(.login(password: password))
    }

    func getLatestGlucose() async throws -> GlucoseEntry {
        try await request(.glucoseLatest)
    }

    func getGlucoseRange(startDate: String, endDate: String) async throws -> [GlucoseEntry] {
        try await request(.glucoseRange(startDate: startDate, endDate: endDate))
    }

    func getAnalytics(startDate: String, endDate: String, thresholds: AlarmThresholds) async throws -> GlucoseAnalytics {
        try await request(.analytics(startDate: startDate, endDate: endDate, thresholds: thresholds))
    }

    func detectPatterns(startDate: String, endDate: String) async throws -> [DetectedPattern] {
        try await request(.detectPatterns(startDate: startDate, endDate: endDate))
    }

    func getTreatments(startDate: String, endDate: String, limit: Int = 500, eventType: String? = nil) async throws -> [Treatment] {
        try await request(.getTreatments(startDate: startDate, endDate: endDate, limit: limit, eventType: eventType))
    }

    func createTreatment(body: [String: Any]) async throws -> Treatment {
        try await request(.createTreatment(body: body))
    }

    func deleteTreatment(id: String) async throws -> Bool {
        let _: APIResponse<String> = try await request(.deleteTreatment(id: id))
        return true
    }

    func getSettings() async throws -> AppSettings {
        try await request(.getSettings)
    }

    func saveSettings(_ settings: AppSettings) async throws -> AppSettings {
        try await request(.saveSettings(body: settings))
    }

    func getCalendarData(startDate: String, endDate: String) async throws -> [CalendarDayData] {
        try await request(.calendarData(startDate: startDate, endDate: endDate))
    }

    func getDistributionStats(startDate: String, endDate: String, thresholds: AlarmThresholds) async throws -> DistributionStats {
        try await request(.distributionStats(startDate: startDate, endDate: endDate, thresholds: thresholds))
    }

    func getDailyPatterns(startDate: String, endDate: String) async throws -> [DailyPattern] {
        try await request(.dailyPatterns(startDate: startDate, endDate: endDate))
    }
}
