import SwiftUI

@main
struct DayDeltaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}

/// Custom tab container. Tabs: Accounts(0, default) / Ledger(1) / Stats(2) / Days(3).
/// ponytail: a plain TabView can't animate its content swap; this trades tab state
/// preservation (views reload from their stores on switch, which is cheap) for a
/// directional slide + haptic. The slide direction follows the index delta.
private struct RootView: View {
    @State private var tab = 0
    @State private var prevTab = 0
    @State private var requestAddTxn = false

    /// Horizontal slide whose direction follows whether we moved to a higher or
    /// lower tab index — new page in from the far side, old page out the near side.
    private var slide: AnyTransition {
        let forward = tab >= prevTab
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
                .id(tab)
                .transition(slide)
        }
        .safeAreaInset(edge: .bottom) { tabBar }
        .sensoryFeedback(.selection, trigger: tab)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case 0:  AccountsView()
        case 1:  LedgerView(requestAddTxn: $requestAddTxn)
        case 2:  StatsView()
        default: ContentView()
        }
    }

    /// Floating honey-themed pill: circular icon buttons, the active one on an
    /// amber disc. Translucent material so it reads on both the light Accounts
    /// page and the dark tabs.
    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton(0, "creditcard")
            tabButton(1, "calendar.day.timeline.left")
            if tab == 1 {
                addButton
                    .transition(.scale.combined(with: .opacity))
            }
            tabButton(2, "chart.pie")
            tabButton(3, "calendar")
        }
        .padding(6)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Color(hex: "#F59E0B").opacity(0.25)))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .padding(.horizontal, 32)
        .padding(.bottom, 4)
    }

    /// Center Add — only present on the Ledger tab. Its insertion/removal rides the
    /// tab-switch `.bouncy` animation, so it springs in / collapses out silkily.
    private var addButton: some View {
        Button {
            requestAddTxn = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(hex: "#78350F"))
                .frame(width: 52, height: 52)
                .background(Circle().fill(LinearGradient(
                    colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")],
                    startPoint: .top, endPoint: .bottom)))
                .offset(y: -10)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: requestAddTxn)
    }

    private func tabButton(_ i: Int, _ icon: String) -> some View {
        Button {
            guard tab != i else { return }
            prevTab = tab
            withAnimation(.bouncy(duration: 0.5)) { tab = i }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tab == i ? Color(hex: "#78350F") : .primary.opacity(0.65))
                .frame(width: 50, height: 50)
                .background(Circle().fill(tab == i ? Color(hex: "#F59E0B") : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.3), value: tab)
    }
}
