import SwiftUI

struct ContentView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        Group {
            if authStore.isAuthenticated {
                MainNavigationView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authStore.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environment(AuthStore())
        .environment(DashboardStore())
}
