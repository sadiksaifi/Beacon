import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Connections", systemImage: "network") {
                ConnectionsView()
            }

            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
    }
}

#Preview {
    MainTabView()
}
