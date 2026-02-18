import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Connections", systemImage: "network") {
                ConnectionsView()
            }
            .accessibilityLabel("Connections tab")

            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
            .accessibilityLabel("Settings tab")
        }
    }
}

#Preview {
    MainTabView()
}
