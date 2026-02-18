import SwiftData
import SwiftUI

@main
struct BeaconApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: Connection.self)
    }
}
