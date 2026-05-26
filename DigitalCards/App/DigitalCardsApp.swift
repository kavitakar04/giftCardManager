import SwiftData
import SwiftUI

@main
struct DigitalCardsApp: App {
    @StateObject private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            CardLibraryView()
                .environmentObject(environment)
        }
        .modelContainer(for: [StoredCard.self, BalanceAdjustment.self])
    }
}
