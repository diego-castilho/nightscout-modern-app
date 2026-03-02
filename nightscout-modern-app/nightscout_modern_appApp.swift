import SwiftUI

@main
struct nightscout_modern_appApp: App {
    @State private var authStore = AuthStore()
    @State private var dashboardStore = DashboardStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authStore)
                .environment(dashboardStore)
                .preferredColorScheme(dashboardStore.appTheme.colorScheme)
        }
    }
}
