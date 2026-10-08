import SwiftUI
import LocalAuthentication

/// Optional Face ID / Touch ID / passcode gate. When enabled, the app is locked on
/// launch and whenever it returns from the background, until the owner authenticates.
@Observable final class LockManager {
    static let shared = LockManager()
    // Only start locked if the feature is on (read the flag directly — `enabled`
    // is a computed property and can't be used before init finishes).
    private init() { locked = UserDefaults.standard.bool(forKey: "appLockEnabled") }

    private var enabled: Bool { UserDefaults.standard.bool(forKey: "appLockEnabled") }
    /// Whether the lock screen is showing. Only ever true when `enabled`.
    var locked: Bool
    /// A prompt is in flight — blocks re-entrant calls so the biometric sheet
    /// flipping scenePhase can't spawn a second prompt (the infinite-loop bug).
    private var authenticating = false

    /// Re-lock (on backgrounding). No-op when the feature is off.
    func lock() { locked = enabled }

    /// Prompt once. Ignored if off, already unlocked, or a prompt is in flight.
    func authenticate() {
        guard enabled, locked, !authenticating else { return }
        authenticating = true
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Enter Passcode"
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authenticating = false; locked = false; return   // no biometrics/passcode → don't trap the user
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock DayDelta") { ok, _ in
            Task { @MainActor in
                self.authenticating = false
                if ok { self.locked = false }
            }
        }
    }
}

/// Full-screen cover shown while locked. Prompts once on appear; the button retries.
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
        .task { onUnlock() }   // auto-prompt once when the lock screen appears
    }
}
