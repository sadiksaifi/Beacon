import Testing
@testable import Beacon

@Suite("App Launch")
struct AppLaunchTests {
    @Test @MainActor func mainTabViewInstantiates() {
        let view = MainTabView()
        _ = view
    }

    @Test @MainActor func connectionsViewInstantiates() {
        let view = ConnectionsView()
        _ = view
    }

    @Test @MainActor func settingsViewInstantiates() {
        let view = SettingsView()
        _ = view
    }

    @Test @MainActor func emptyStateViewInstantiates() {
        let view = ConnectionsEmptyStateView(onAddConnection: {})
        _ = view
    }
}
