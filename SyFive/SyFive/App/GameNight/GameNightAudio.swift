import SwiftUI
import SyLibFeel

// During Game Night, Mix with Other Audio plays as Game Audio Only: mixed game audio echoes in
// the FaceTime call (33 §2.1, D-193). The saved setting is never rewritten.
enum GameNightAudio {
    static func effectiveSoundMode(_ saved: AppSoundMode, gameNightActive: Bool) -> AppSoundMode {
        gameNightActive && saved == .mix ? .exclusive : saved
    }
    static func choices(gameNightActive: Bool) -> [AppSoundMode] {
        gameNightActive ? [.off, .exclusive] : AppSoundMode.allCases
    }
    static let footerNote = "During Game Night, SyFive plays as Game Audio Only, so the call doesn't echo."
}

extension EnvironmentValues {
    // Whether a Game Night session is active, for Settings' Sound row (33 §2.1).
    @Entry var gameNightAudioActive = false
}
