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
    @State private var appeared = false
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
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.96)
        .sensoryFeedback(.selection, trigger: tab)
        .task {
            withAnimation(.smooth(duration: 0.5)) { appeared = true }   // launch entrance
        }
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

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(0, "Accounts", "creditcard")
            tabButton(1, "Ledger", "calendar.day.timeline.left")
            if tab == 1 {
                addButton
                    .transition(.scale.combined(with: .opacity))
            }
            tabButton(2, "Stats", "chart.pie")
            tabButton(3, "Days", "calendar")
        }
        .padding(.top, 8)
        .background(.black)
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5)
        }
    }

    /// Center Add — only present on the Ledger tab. Its insertion/removal rides the
    /// tab-switch `.bouncy` animation, so it springs in / collapses out silkily.
    private var addButton: some View {
        Button {
            requestAddTxn = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 56, height: 56)
                .background(Circle().fill(.white))
                .offset(y: -12)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: requestAddTxn)
    }

    private func tabButton(_ i: Int, _ title: String, _ icon: String) -> some View {
        Button {
            guard tab != i else { return }
            prevTab = tab
            withAnimation(.bouncy(duration: 0.5)) { tab = i }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20))
                Text(title).font(.system(.caption2, design: .monospaced))
            }
            .foregroundStyle(tab == i ? Color.white : .gray)
            .scaleEffect(tab == i ? 1.0 : 0.9)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.3), value: tab)
    }
}
