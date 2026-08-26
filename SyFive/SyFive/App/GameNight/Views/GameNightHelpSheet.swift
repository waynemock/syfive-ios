import SwiftUI
import SyLibScoring

/// Context-sensitive onboarding sheet for Game Night SharePlay.
/// Covers four meaningful states: pre-session, host waiting for guests, guest accepting, guest already connected.
struct GameNightHelpSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    enum Context {
        case preSession   // no session started yet (may or may not be on a call)
        case hosting      // host sent invite or game is running
        case joining      // guest waiting to accept the invitation
        case joined       // guest already connected but dismissed the table view
    }

    let context: Context
    /// Whether the device is currently in a FaceTime call or iMessage thread.
    /// When false in the preSession context, a prerequisites section is shown first.
    let isEligibleForGroupSession: Bool

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        NavigationStack {
            List {
                switch context {
                case .preSession: preSessionSections
                case .hosting:    hostingSections
                case .joining:    joiningSections
                case .joined:     joinedSections
                }
            }
            .navigationTitle("Game Night Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Pre-session

    @ViewBuilder
    private var preSessionSections: some View {
        if !isEligibleForGroupSession {
            Section {
                Text("Game Night plays alongside FaceTime or Messages. Before you can start a game night, you need one of these open with your players:")
                    .listRowBackground(Color.clear)
                Label {
                    Text("FaceTime call — video or audio")
                } icon: {
                    Image(systemName: "video.fill")
                        .foregroundStyle(.green)
                }
                .listRowBackground(Color.clear)
                Label {
                    Text("Messages conversation — an existing group thread works too")
                } icon: {
                    Image(systemName: "message.fill")
                        .foregroundStyle(.green)
                }
                .listRowBackground(Color.clear)
                Text("Tap **Start Game Night** in the menu to connect a FaceTime call or a Messages thread without leaving SyFive.")
                    .listRowBackground(Color.clear)
                Text("Alternately, start a FaceTime call first as you normally would, and return to SyFive to start a game night.")
                    .listRowBackground(Color.clear)
            } header: {
                Text("Start with a call or a conversation")
                    .foregroundStyle(theme.primaryAccent)
            }
        }
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.body)
                    .foregroundStyle(theme.primaryAccent)
                    .padding(.top, 2)
                Text("Tap the **Game Night** button in the navigation bar to invite everyone on your call. You become the host and a table setup screen appears.")
            }
            .listRowBackground(Color.clear)
        } header: {
            Text("Hosting a game night")
                .foregroundStyle(theme.primaryAccent)
        }
        Section {
            Text("If your host has already started, a notification will appear briefly at the top of your screen. Tap it to join.")
                .listRowBackground(Color.clear)
            Text("If you missed it, the SharePlay button stays visible until the session ends.")
                .listRowBackground(Color.clear)
            thisDeviceSharePlayRow
        } header: {
            Text("Already invited?")
                .foregroundStyle(theme.primaryAccent)
        }
    }

    // MARK: - Hosting

    @ViewBuilder
    private var hostingSections: some View {
        Section {
            Text("Tell your guests to watch for a **Game Night** notification — it appears briefly at the top of their screen and goes away after about 15 seconds.")
                .listRowBackground(Color.clear)
        } header: {
            Text("Your guests need to accept")
                .foregroundStyle(theme.primaryAccent)
        }
        Section {
            Text("The SharePlay button stays visible after the notification disappears. Tell them to find it on their device:")
                .listRowBackground(Color.clear)
            sharePlayRow(
                badge: .phone,
                label: "iPhone — Dynamic Island",
                detail: "Green SharePlay icon at the very top of the screen, inside the pill-shaped cutout."
            )
            sharePlayRow(
                badge: .pad,
                label: "iPad — Navigation Bar",
                detail: "White SharePlay icon on a solid green capsule in the top navigation bar."
            )
        } header: {
            Text("If a guest missed the notification")
                .foregroundStyle(theme.primaryAccent)
        }
    }

    // MARK: - Joining

    @ViewBuilder
    private var joiningSections: some View {
        Section {
            Text("Your host has started Game Night. A notification will appear briefly at the top of your screen — tap it to join.")
                .listRowBackground(Color.clear)
        } header: {
            Text("Accepting the invitation")
                .foregroundStyle(theme.primaryAccent)
        }
        Section {
            Text("The SharePlay button stays visible after the notification disappears. Tap it to get back to the invitation.")
                .listRowBackground(Color.clear)
            thisDeviceSharePlayRow
        } header: {
            Text("Missed the notification?")
                .foregroundStyle(theme.primaryAccent)
        }
    }

    // MARK: - Already joined (connected but table dismissed)

    @ViewBuilder
    private var joinedSections: some View {
        Section {
            Text("You're already connected to this Game Night session — no need to accept anything.")
                .listRowBackground(Color.clear)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.body)
                    .foregroundStyle(theme.primaryAccent)
                    .padding(.top, 2)
                Text("Tap the **Game Night** button in the navigation bar to reopen the table and claim your seat.")
            }
            .listRowBackground(Color.clear)
        } header: {
            Text("Return to the table")
                .foregroundStyle(theme.primaryAccent)
        }
        Section {
            Text("Once everyone has claimed a seat, the host taps **Start** and the scorecard appears.")
                .listRowBackground(Color.clear)
        } header: {
            Text("What happens next")
                .foregroundStyle(theme.primaryAccent)
        }
    }

    // MARK: - SharePlay badge rows

    /// Shows the SharePlay button location for the current device.
    @ViewBuilder
    private var thisDeviceSharePlayRow: some View {
        if isIPad {
            sharePlayRow(
                badge: .pad,
                label: "In the navigation bar",
                detail: "Tap the white SharePlay icon on the green capsule at the top of the screen."
            )
        } else {
            sharePlayRow(
                badge: .phone,
                label: "In the Dynamic Island",
                detail: "Tap the green SharePlay icon at the very top of your screen."
            )
        }
    }

    private enum BadgeStyle { case phone, pad }

    private func sharePlayRow(badge: BadgeStyle, label: String, detail: String) -> some View {
        HStack(spacing: 16) {
            sharePlayBadge(badge)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.subheadline).fontWeight(.semibold)
                Text(detail)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func sharePlayBadge(_ style: BadgeStyle) -> some View {
        switch style {
        case .phone:
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black)
                    .frame(width: 48, height: 48)
                Image(systemName: "shareplay")
                    .foregroundStyle(.green)
                    .font(.system(size: 22, weight: .semibold))
            }
        case .pad:
            ZStack {
                Capsule()
                    .fill(.green)
                    .frame(width: 60, height: 34)
                Image(systemName: "shareplay")
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .semibold))
            }
        }
    }
}

#Preview("Not on a call") {
    GameNightHelpSheet(context: .preSession, isEligibleForGroupSession: false)
}

#Preview("On a call") {
    GameNightHelpSheet(context: .preSession, isEligibleForGroupSession: true)
}

#Preview("Hosting") {
    GameNightHelpSheet(context: .hosting, isEligibleForGroupSession: true)
}

#Preview("Joined (need to reclaim seat)") {
    GameNightHelpSheet(context: .joined, isEligibleForGroupSession: true)
}
