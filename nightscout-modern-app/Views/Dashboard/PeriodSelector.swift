import SwiftUI

struct PeriodSelector: View {
    @Binding var period: Period

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Period.allCases) { p in
                Button(p.label) {
                    period = p
                }
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(period == p ? Color.accentColor : Color.clear)
                .foregroundStyle(period == p ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(period == p ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}
