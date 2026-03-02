import SwiftUI

@main
struct DCGlycoApp: App {
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
