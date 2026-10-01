import SwiftUI

@main
struct DayDeltaApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Days", systemImage: "calendar") }
                LedgerView()
                    .tabItem { Label("Money", systemImage: "dollarsign.circle") }
            }
            .preferredColorScheme(.dark)
            .tint(.white)
        }
    }
}
