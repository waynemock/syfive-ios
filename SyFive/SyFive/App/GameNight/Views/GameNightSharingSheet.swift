import SwiftUI
import SyLibScoring
import UIKit
import GroupActivities
import SyLibCore

/// Presents GroupActivitySharingController imperatively from the topmost UIViewController.
/// The controller supports both FaceTime (active or new) and iMessage threads as transports.
/// In dev builds the people-picker XPC extension is sandbox-restricted, so the controller
/// auto-dismisses immediately with .cancelled; we detect that via elapsed time and show
/// GameNightInviteInstructions after a short delay to avoid a presentation conflict while
/// the auto-dismiss animation is still running. In TestFlight/App Store the full flow works.
@MainActor
enum GameNightSharing {
    private static let logger = AppLogger(category: "GameNightSharing")

    /// `onDismissed` is always called once the UIKit controller is gone (success OR cancel).
    /// `onCancelled` is called when the user explicitly cancelled (slow cancel, elapsed >= 1s) —
    /// use it to clean up isSessionPending. `onRequiresConversation` is called for fast-cancel
    /// (sandbox auto-dismiss) to show invite instructions.
    static func present(
        onRequiresConversation: @escaping () -> Void,
        onDismissed: @escaping () -> Void = {},
        onCancelled: @escaping () -> Void = {}
    ) {
        guard let controller = try? GroupActivitySharingController(GameNightActivity()),
              let topVC = topmostViewController() else {
            logger.info(logger, "present: controller or topVC unavailable — calling onRequiresConversation")
            onRequiresConversation()
            return
        }
        logger.info(logger, "present: presenting GroupActivitySharingController over \(String(describing: type(of: topVC)))")
        let presentedAt = Date()
        topVC.present(controller, animated: true)
        Task { @MainActor in
            let outcome = await controller.result
            let elapsed = Date().timeIntervalSince(presentedAt)
            logger.info(logger, "present: controller result=\(String(describing: outcome)) elapsed=\(String(format: "%.2f", elapsed))s")
            logger.info(logger, "present: calling onDismissed")
            onDismissed()
            guard case .cancelled = outcome else { return }
            if elapsed < 1.0 {
                logger.info(logger, "present: fast-cancel detected, sleeping 0.6s then calling onRequiresConversation")
                try? await Task.sleep(nanoseconds: 600_000_000)
                onRequiresConversation()
            } else {
                logger.info(logger, "present: slow-cancel detected, calling onCancelled")
                onCancelled()
            }
        }
    }

    private static func topmostViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        guard let root = scene?.keyWindow?.rootViewController else { return nil }
        var top = root
        while let next = top.presentedViewController { top = next }
        return top
    }
}

/// Shown when the host taps the pending nav bar button after sending a Messages invite.
/// With Messages SharePlay (unlike FaceTime), the sender's GroupSession only arrives when
/// they explicitly open the SharePlay banner iOS shows when a recipient joins. This sheet
/// explains that step so the host isn't left tapping a dead cancel alert.
struct GameNightPendingSheet: View {
    var onCancelInvite: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Your invite has been sent. When players tap the link in Messages, their Game Night seating screen will open automatically.")
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Waiting for players")
                        .foregroundStyle(theme.primaryAccent)
                }
                Section {
                    Text("When a player joins, a SharePlay banner appears. Tap it, then tap **Open** to enter the session.")
                        .listRowBackground(Color.clear)
                    SharePlayLocationRow()
                } header: {
                    Text("How to join on your device")
                        .foregroundStyle(theme.primaryAccent)
                }
                Section {
                    Button("Cancel Invite", role: .destructive) {
                        dismiss()
                        onCancelInvite()
                    }
                }
            }
            .navigationTitle("Invite Sent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Device-adaptive SharePlay button badge + location description.
/// Mirrors the badge style used in GameNightHelpSheet.
private struct SharePlayLocationRow: View {
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        HStack(spacing: 16) {
            badge
            VStack(alignment: .leading, spacing: 3) {
                Text(isIPad ? "Navigation bar" : "Top of your screen")
                    .font(.subheadline).fontWeight(.semibold)
                Text(isIPad
                     ? "Tap the white SharePlay icon on the green capsule in the navigation bar."
                     : "Tap the green SharePlay icon at the very top of your screen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var badge: some View {
        if isIPad {
            ZStack {
                Capsule()
                    .fill(.green)
                    .frame(width: 60, height: 34)
                Image(systemName: "shareplay")
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .semibold))
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black)
                    .frame(width: 48, height: 48)
                Image(systemName: "shareplay")
                    .foregroundStyle(.green)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
    }
}

#Preview("Pending — Messages invite sent") {
    GameNightPendingSheet(onCancelInvite: {})
        .environment(\.theme, Theme(type: .midnight, colorScheme: .dark))
}

/// Shown when GroupActivitySharingController auto-dismisses (dev-build sandbox restriction).
/// In production this sheet should only appear when there is genuinely no FaceTime call
/// or iMessage thread available to share into.
struct GameNightInviteInstructions: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("SharePlay requires a FaceTime call or Messages conversation. Start one with your players, then tap **Invite Players** again — no ongoing call needed, just an existing conversation.")
                        .listRowBackground(Color.clear)
                    SharePlayLocationRow()
                } header: {
                    Text("A conversation is required")
                        .foregroundStyle(theme.primaryAccent)
                }
                Section {
                    Button {
                        openURL(URL(string: "facetime://")!)
                    } label: {
                        Label("Open FaceTime", systemImage: "video.fill")
                    }
                    .tint(.green)
                    Button {
                        openURL(URL(string: "messages://")!)
                    } label: {
                        Label("Open Messages", systemImage: "message.fill")
                    }
                    .tint(.green)
                }
            }
            .navigationTitle("Invite Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview("Invite instructions — no conversation") {
    GameNightInviteInstructions()
        .environment(\.theme, Theme(type: .midnight, colorScheme: .dark))
}
