import SwiftUI

@main
struct DayDeltaApp: App {
    init() { AppGroup.migrateOnce() }   // move existing data into the shared app group

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}

/// Custom tab container. Tabs: Accounts(0) / Ledger(1) / Stats(2) / Days(3) / Invest(4).
/// A custom offset pager over one shared, fixed grainient background: transparent
/// pages follow the finger (content swipe + tab-bar drag), snapping on release.
private struct RootView: View {
    /// Fractional page position (0…3). Both the content swipe and the tab-bar
    /// drag drive this continuously, so pages follow the finger in real time.
    @State private var progress: CGFloat = 0
    @State private var barWidth: CGFloat = 0
    @State private var requestAddTxn = false
    @Namespace private var tabNS
    /// Observed so the tab bar's ink recomputes when the background color changes.
    @AppStorage("accountsBgHex") private var bgHex = "#5227FF"
    /// Accent color for the selected-tab highlight and Add button.
    @AppStorage("accentHex") private var accentHex = "#5227FF"
    /// Panel color drives the tab bar fill; observed so it updates live.
    @AppStorage("panelHex") private var panelHex = "#FFFFFF26"
    @Environment(\.scenePhase) private var scenePhase
    @State private var lock = LockManager.shared

    /// Nearest page — drives the highlight, Add button, and haptics.
    private var tab: Int { Int(progress.rounded()) }

    var body: some View {
        let _ = (bgHex, panelHex)   // subscribe so ink + panel color update live
        ZStack {
            // One fixed animated grainient behind everything. Pages are transparent
            // and slide over it, so the background never seams or flashes black.
            GrainientBackground().ignoresSafeArea()
            pager
        }
        .safeAreaInset(edge: .bottom) { tabBar }
        .sensoryFeedback(.selection, trigger: tab)
        .fontDesign(.rounded)
        .fontWeight(.thin)
        .fullScreenCover(isPresented: Binding(get: { lock.locked }, set: { _ in })) {
            LockScreen { lock.authenticate() }   // LockScreen auto-prompts on appear
        }
        // Re-lock when leaving the foreground; the cover's own .task re-prompts on
        // return. We do NOT auth on .active (the biometric sheet toggles scenePhase,
        // which would otherwise loop).
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lock.lock() }
        }
    }

    /// Custom offset pager: four full-width pages in a row, shifted by `progress`.
    /// A horizontal drag scrubs it; vertical drags pass through to lists/scrolls
    /// (simultaneousGesture + a horizontal gate), so nested scrolling still works.
    private var pager: some View {
        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    page(i).frame(width: w)
                }
            }
            .frame(width: w * 5, alignment: .leading)
            .offset(x: -progress * w)
            // Pages switch only via the tab bar (tap or drag) — no content swipe,
            // so horizontal gestures inside a page (e.g. chart scrubbing) are free.
        }
    }

    private func clampPage(_ x: CGFloat) -> CGFloat { min(4, max(0, x)) }

    @ViewBuilder
    private func page(_ i: Int) -> some View {
        switch i {
        case 0:  AccountsView()
        case 1:  LedgerView(requestAddTxn: $requestAddTxn)
        case 2:  StatsView()
        case 3:  ContentView()
        default: InvestmentsView()
        }
    }

    /// Animate to a page (from a tab tap).
    private func go(to i: Int) {
        guard i >= 0, i <= 4, CGFloat(i) != progress else { return }
        withAnimation(.bouncy(duration: 0.45)) { progress = CGFloat(i) }
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
            tabButton(4, "chart.line.uptrend.xyaxis")
        }
        .padding(6)
        .background(GeometryReader { g in
            Color.clear
                .onAppear { barWidth = g.size.width }
                .onChange(of: g.size.width) { _, w in barWidth = w }
        })
        // Press-drag across the bar to scrub pages in real time: the finger's x
        // maps straight to the fractional page, so pages follow the finger.
        // simultaneousGesture so it works even over the buttons; snaps on release.
        .simultaneousGesture(DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard barWidth > 0 else { return }
                progress = clampPage(v.location.x / (barWidth / 5) - 0.5)
            }
            .onEnded { _ in
                withAnimation(Motion.quick) { progress = CGFloat(tab) }
            })
        .panel()
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
                .background(RoundedRectangle(cornerRadius: UI.radius)
                    .fill(accentGradient(accentHex)).padding(3))
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
