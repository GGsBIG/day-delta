import SwiftUI

@main
struct DayDeltaApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Days", systemImage: "calendar") }
                LedgerView()
                    .tabItem { Label("記帳", systemImage: "dollarsign.circle") }
            }
            .preferredColorScheme(.dark)
            .tint(.white)
        }
    }
}
