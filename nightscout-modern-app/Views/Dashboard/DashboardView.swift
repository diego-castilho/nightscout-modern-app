import SwiftUI

struct DashboardView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(DashboardStore.self) private var store

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(spacing: 12) {
                // Period selector + summary
                HStack {
                    PeriodSelector(period: $store.period)
                    Spacer()
                    if let analytics = store.analytics {
                        Text("\(analytics.totalReadings) leituras · \(Int(analytics.period.days))d")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)

                // Current glucose
                CurrentGlucoseCard()

                // Glucose chart
                GlucoseAreaChartView()

                // Stats grid
                StatsGridView()

                // TIR + Daily Pattern
                ViewThatFits(in: .horizontal) {
                    // Wide layout: side by side
                    HStack(alignment: .top, spacing: 12) {
                        TIRChartView()
                            .frame(maxWidth: .infinity)
                        DailyPatternChartView()
                            .frame(maxWidth: .infinity)
                    }
                    // Narrow layout: stacked
                    VStack(spacing: 12) {
                        TIRChartView()
                        DailyPatternChartView()
                    }
                }

                // Patterns alert
                PatternsAlertView()

                // Debug log (temporary — remove after debugging)
                if !store.debugLog.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Debug API Log")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(store.debugLog, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(line.hasPrefix("❌") ? .red : .green)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            async let data: () = store.refreshData()
            async let patterns: () = store.refreshPatterns()
            async let iobcob: () = store.refreshIOBCOB()
            async let ages: () = store.refreshDeviceAges()
            _ = await (data, patterns, iobcob, ages)
        }
        .task {
            store.apiClient = authStore.apiClient
            await initialLoad()
        }
        .onChange(of: store.period) { _, _ in
            Task {
                await store.refreshData()
                await store.refreshPatterns()
            }
        }
    }

    private func initialLoad() async {
        // Load settings first
        if let client = authStore.apiClient {
            store.apiClient = client
            do {
                let settings = try await client.getSettings()
                store.initFromServer(settings)
            } catch {
                // Use defaults
            }
        }

        // Parallel data load
        async let data: () = store.refreshData()
        async let patterns: () = store.refreshPatterns()
        async let iobcob: () = store.refreshIOBCOB()
        async let ages: () = store.refreshDeviceAges()
        _ = await (data, patterns, iobcob, ages)

        // Start periodic refresh
        store.startTimers()
    }
}
