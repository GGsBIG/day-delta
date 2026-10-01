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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                if tab == 0 {
                    ContentView()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    LedgerView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .safeAreaInset(edge: .bottom) { tabBar }
        .sensoryFeedback(.selection, trigger: tab)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(0, "Days", "calendar")
            tabButton(1, "Money", "dollarsign.circle")
        }
        .padding(.top, 8)
        .background(.black)
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5)
        }
    }

    private func tabButton(_ i: Int, _ title: String, _ icon: String) -> some View {
        Button {
            guard tab != i else { return }
            withAnimation(.smooth(duration: 0.4)) { tab = i }
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
