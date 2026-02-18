import SwiftData
import SwiftUI

@main
struct BeaconApp: App {
    @State private var keyStore = SSHKeyStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(keyStore)
        }
        .modelContainer(for: Connection.self)
    }
}
