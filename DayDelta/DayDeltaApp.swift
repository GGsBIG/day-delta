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
    @Namespace private var tabNS
    /// Observed so the tab bar's ink recomputes when the background color changes.
    @AppStorage("accountsBgHex") private var bgHex = "#5227FF"
    /// Accent color for the selected-tab highlight and Add button.
    @AppStorage("accentHex") private var accentHex = "#5227FF"

    /// Horizontal slide whose direction follows whether we moved to a higher or
    /// lower tab index — new page in from the far side, old page out the near side.
    private var slide: AnyTransition {
        let forward = tab >= prevTab
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    var body: some View {
        let _ = bgHex   // subscribe to background-color changes so ink updates
        ZStack {
            GrainientBackground().ignoresSafeArea()
            content
                .id(tab)
                .transition(slide)
        }
        .safeAreaInset(edge: .bottom) { tabBar }
        .sensoryFeedback(.selection, trigger: tab)
        .fontDesign(.rounded)
        .fontWeight(.thin)
        // Swipe left/right anywhere to move between tabs.
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { v in
                    guard abs(v.translation.width) > 70,
                          abs(v.translation.width) > abs(v.translation.height) * 1.3 else { return }
                    switchTab(by: v.translation.width < 0 ? 1 : -1)
                }
        )
    }

    /// Step the active tab, clamped to 0...3, with the directional slide.
    private func switchTab(by delta: Int) {
        let next = tab + delta
        guard next >= 0, next <= 3, next != tab else { return }
        prevTab = tab
        withAnimation(.bouncy(duration: 0.5)) { tab = next }
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

    /// Glass pill: frosted capsule with circular icon buttons. The active tab's
    /// highlight glides between slots via matchedGeometry, so switching is silky.
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
        .liquidGlass()
        .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
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
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(Circle().fill(accentGradient(accentHex)))
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
                .foregroundStyle(tab == i ? .white : Color.appInk.opacity(0.55))
                .frame(width: 50, height: 50)
                .background {
                    if tab == i {
                        Circle()
                            .fill(accentGradient(accentHex))
                            .matchedGeometryEffect(id: "tabHighlight", in: tabNS)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
