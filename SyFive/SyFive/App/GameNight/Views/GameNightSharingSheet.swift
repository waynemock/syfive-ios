import SwiftUI
import UIKit
import GroupActivities

/// Presents GroupActivitySharingController imperatively from the topmost UIViewController.
/// The controller supports both FaceTime (active or new) and iMessage threads as transports.
/// In dev builds the people-picker XPC extension is sandbox-restricted, so the controller
/// auto-dismisses immediately with .cancelled; we detect that via elapsed time and show
/// GameNightInviteInstructions after a short delay to avoid a presentation conflict while
/// the auto-dismiss animation is still running. In TestFlight/App Store the full flow works.
@MainActor
enum GameNightSharing {
    private static let logger = AppLogger(category: "GameNightSharing")

    /// `onDismissed` is always called once the UIKit controller is gone (success OR fast-cancel).
    /// Use it to re-show the Game Night seating sheet if the session arrived while the
    /// controller was on screen (Messages SharePlay delivers the session before the modal
    /// dismisses, but iOS resets SwiftUI's isPresented binding when a UIKit modal takes over).
    static func present(
        onRequiresConversation: @escaping () -> Void,
        onDismissed: @escaping () -> Void = {}
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
            // Always notify that the UIKit modal is now gone.
            logger.info(logger, "present: calling onDismissed")
            onDismissed()
            guard case .cancelled = outcome,
                  elapsed < 1.0 else { return }
            logger.info(logger, "present: fast-cancel detected, sleeping 0.6s then calling onRequiresConversation")
            // Let the auto-dismiss animation finish before SwiftUI presents the next sheet.
            try? await Task.sleep(nanoseconds: 600_000_000)
            onRequiresConversation()
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

/// Shown when GroupActivitySharingController auto-dismisses (dev-build sandbox restriction).
/// In production this sheet should only appear when there is genuinely no FaceTime call
/// or iMessage thread available to share into.
struct GameNightInviteInstructions: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("SharePlay requires a FaceTime call or iMessage thread. Start one with your players, then tap **Invite Players** again — no ongoing call needed, just an existing conversation.")
                        .listRowBackground(Color.clear)
                } header: {
                    Text("A conversation is required")
                }
                Section {
                    Button {
                        openURL(URL(string: "facetime://")!)
                    } label: {
                        Label("Open FaceTime", systemImage: "video.fill")
                    }
                    Button {
                        openURL(URL(string: "messages://")!)
                    } label: {
                        Label("Open Messages", systemImage: "message.fill")
                    }
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
