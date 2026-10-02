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

/// Custom tab container so switching Days <-> Money slides directionally.
/// ponytail: a plain TabView can't animate its content swap; this trades tab
/// state preservation (views reload from their stores on switch, which is cheap)
/// for the slide + haptic. Two tabs only, so fixed per-view edges already give
/// the correct left/right direction both ways.
private struct RootView: View {
    @State private var tab = 0
    @State private var requestAddTxn = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                switch tab {
                case 0:
                    ContentView()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                case 1:
                    LedgerView(requestAddTxn: $requestAddTxn)
                        .transition(.opacity)
                case 2:
                    StatsView()
                        .transition(.opacity)
                default:
                    AccountsView()
                        .transition(.opacity)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { tabBar }
        .sensoryFeedback(.selection, trigger: tab)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(0, "Days", "calendar")
            tabButton(1, "Ledger", "calendar.day.timeline.left")
            if tab == 1 {
                addButton
                    .transition(.scale.combined(with: .opacity))
            }
            tabButton(2, "Stats", "chart.pie")
            tabButton(3, "Accounts", "creditcard")
        }
        .padding(.top, 8)
        .background(.black)
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5)
        }
    }

    /// Center Add — only present on the Money tab. Its insertion/removal rides the
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
