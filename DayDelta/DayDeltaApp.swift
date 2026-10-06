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
    /// Highlight / Add-button / haptics follow this; mirrors the scroll position.
    @State private var tab = 0
    /// The paging scroll view's current page id (two-way bound).
    @State private var scrolledTab: Int? = 0
    @State private var barWidth: CGFloat = 0
    @State private var requestAddTxn = false
    @Namespace private var tabNS
    /// Observed so the tab bar's ink recomputes when the background color changes.
    @AppStorage("accountsBgHex") private var bgHex = "#5227FF"
    /// Accent color for the selected-tab highlight and Add button.
    @AppStorage("accentHex") private var accentHex = "#5227FF"

    var body: some View {
        let _ = bgHex   // subscribe to background-color changes so ink updates
        ZStack {
            // Static base behind the pager (cheap). Each page draws its own
            // animated grainient on top; all share the same color + wall clock,
            // so they render identical frames and paging looks seamless.
            GrainientBackground(animated: false).ignoresSafeArea()
            pager
        }
        .safeAreaInset(edge: .bottom) { tabBar }
        .sensoryFeedback(.selection, trigger: tab)
        .fontDesign(.rounded)
        .fontWeight(.thin)
        // A settled swipe updates the page id; glide the highlight to match.
        .onChange(of: scrolledTab) { _, new in
            guard let new, new != tab else { return }
            withAnimation(.bouncy(duration: 0.4)) { tab = new }
        }
    }

    /// Horizontal, snap-paging scroll of the four pages. No spacing = no gaps.
    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    page(i).containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledTab)
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func page(_ i: Int) -> some View {
        switch i {
        case 0:  AccountsView()
        case 1:  LedgerView(requestAddTxn: $requestAddTxn)
        case 2:  StatsView()
        default: ContentView()
        }
    }

    /// Animate the pager to a page (from a tab tap or a tab-bar drag).
    private func go(to i: Int) {
        guard i >= 0, i <= 3, i != scrolledTab else { return }
        withAnimation(.bouncy(duration: 0.45)) { scrolledTab = i }
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
        .background(GeometryReader { g in
            Color.clear
                .onAppear { barWidth = g.size.width }
                .onChange(of: g.size.width) { _, w in barWidth = w }
        })
        // Press-drag across the bar to scrub pages. simultaneousGesture so it
        // works even over the buttons (which would otherwise swallow the touch);
        // a tap doesn't move far enough to trigger it.
        .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { v in
            guard barWidth > 0 else { return }
            let i = min(3, max(0, Int(v.location.x / (barWidth / 4))))
            if i != scrolledTab { go(to: i) }
        })
        .liquidGlass(clear: true)
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
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
        Button { go(to: i) } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tab == i ? .white : Color.appInk.opacity(0.55))
                .frame(width: 50, height: 50)
                .background {
                    if tab == i {
                        RoundedRectangle(cornerRadius: UI.radius)
                            .fill(accentGradient(accentHex))
                            .padding(3)
                            .matchedGeometryEffect(id: "tabHighlight", in: tabNS)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
