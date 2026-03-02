import SwiftUI

// MARK: - Glucose Zone Colors (matches web glucoseColors.ts)

enum GlucoseColors {
    static let veryLow  = Color(hex: "#b91c1c")  // Red 700
    static let low      = Color(hex: "#ef4444")  // Red 500
    static let inRange  = Color(hex: "#22c55e")  // Green 500
    static let high     = Color(hex: "#f59e0b")  // Amber 500
    static let veryHigh = Color(hex: "#f97316")  // Orange 500
    static let noData   = Color(hex: "#71717a")  // Zinc 500
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "Sistema"
        case .light:  "Claro"
        case .dark:   "Escuro"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light:  "sun.max.fill"
        case .dark:   "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}

// MARK: - Color(hex:) Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8)  & 0xFF) / 255.0
        let b = Double(rgb         & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
