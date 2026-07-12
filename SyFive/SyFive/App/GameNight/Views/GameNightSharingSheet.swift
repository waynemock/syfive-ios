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
    static func present(onRequiresConversation: @escaping () -> Void) {
        guard let controller = try? GroupActivitySharingController(GameNightActivity()),
              let topVC = topmostViewController() else {
            onRequiresConversation()
            return
        }
        let presentedAt = Date()
        topVC.present(controller, animated: true)
        Task { @MainActor in
            let outcome = await controller.result
            guard case .cancelled = outcome,
                  Date().timeIntervalSince(presentedAt) < 1.0 else { return }
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
