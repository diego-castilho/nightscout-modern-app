import Foundation

enum TrendArrow {
    /// Maps Nightscout direction string to arrow character.
    static func symbol(for direction: String?) -> String {
        guard let direction else { return "-" }
        switch direction {
        case "NONE":              return "\u{21FC}"   // ⇼
        case "TripleUp":         return "\u{290A}"   // ⤊
        case "DoubleUp":         return "\u{21C8}"   // ⇈
        case "SingleUp":         return "\u{2191}"   // ↑
        case "FortyFiveUp":      return "\u{2197}"   // ↗
        case "Flat":             return "\u{2192}"   // →
        case "FortyFiveDown":    return "\u{2198}"   // ↘
        case "SingleDown":       return "\u{2193}"   // ↓
        case "DoubleDown":       return "\u{21CA}"   // ⇊
        case "TripleDown":       return "\u{290B}"   // ⤋
        case "NOT COMPUTABLE":   return "-"
        case "RATE OUT OF RANGE": return "\u{21D5}"  // ⇕
        default:                 return "-"
        }
    }

    /// Maps Nightscout direction string to Portuguese description.
    static func description(for direction: String?) -> String {
        guard let direction else { return "Indisponível" }
        switch direction {
        case "NONE":              return "Não calculável"
        case "TripleUp":         return "Subindo muito rápido"
        case "DoubleUp":         return "Subindo rapidamente"
        case "SingleUp":         return "Subindo"
        case "FortyFiveUp":      return "Subindo levemente"
        case "Flat":             return "Estável"
        case "FortyFiveDown":    return "Descendo levemente"
        case "SingleDown":       return "Descendo"
        case "DoubleDown":       return "Descendo rapidamente"
        case "TripleDown":       return "Descendo muito rápido"
        case "NOT COMPUTABLE":   return "Não calculável"
        case "RATE OUT OF RANGE": return "Fora do intervalo"
        default:                 return "Indisponível"
        }
    }
}
