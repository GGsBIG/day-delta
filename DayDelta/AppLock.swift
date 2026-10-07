import SwiftUI
import LocalAuthentication

/// Optional Face ID / Touch ID / passcode gate. When enabled, the app is locked on
/// launch and whenever it returns from the background, until the owner authenticates.
@Observable final class LockManager {
    static let shared = LockManager()
    private init() {}

    private var enabled: Bool { UserDefaults.standard.bool(forKey: "appLockEnabled") }
    /// Locked only matters when the feature is on.
    var locked = true

    /// Lock now (on enabling, or when leaving the foreground).
    func lock() { if enabled { locked = true } }

    /// If off, never locked. If on, prompt the owner; unlock on success.
    func unlockIfNeeded() {
        guard enabled else { locked = false; return }
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Enter Passcode"
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            locked = false; return   // no biometrics/passcode set → don't trap the user
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock DayDelta") { ok, _ in
            Task { @MainActor in if ok { self.locked = false } }
        }
    }
}

/// Full-screen cover shown while locked.
struct LockScreen: View {
    let onUnlock: () -> Void
    var body: some View {
        ZStack {
            GrainientBackground().ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(.white)
                Text("DayDelta is locked").font(.system(.title3, design: .rounded)).bold().foregroundStyle(.white)
                Button("Unlock", action: onUnlock)
                    .font(.system(.headline, design: .rounded)).foregroundStyle(.black)
                    .padding(.vertical, 12).padding(.horizontal, 28)
                    .background(Capsule().fill(.white))
            }
        }
        .preferredColorScheme(.dark)
    }
}
