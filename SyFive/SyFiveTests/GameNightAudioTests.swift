import Testing
import SyLibFeel
@testable import SyFive

// GameNightAudio is main-actor isolated under the app target's default isolation, so the suite
// is too. 33 §2.1, D-193.
@MainActor
struct GameNightAudioTests {

    @Test("In Game Night, Mix plays as Game Audio Only, and Off and Game Audio Only are unchanged")
    func inGameNightMixPlaysAsGameAudioOnly() {
        #expect(GameNightAudio.effectiveSoundMode(.mix, gameNightActive: true) == .exclusive)
        #expect(GameNightAudio.effectiveSoundMode(.off, gameNightActive: true) == .off)
        #expect(GameNightAudio.effectiveSoundMode(.exclusive, gameNightActive: true) == .exclusive)
    }

    @Test("Outside Game Night, every sound mode is unchanged")
    func outsideGameNightEveryModeIsUnchanged() {
        for mode in AppSoundMode.allCases {
            #expect(GameNightAudio.effectiveSoundMode(mode, gameNightActive: false) == mode)
        }
    }

    @Test("Game Night offers Off and Game Audio Only; outside it every mode is offered")
    func gameNightOffersNoMix() {
        #expect(GameNightAudio.choices(gameNightActive: true) == [.off, .exclusive])
        #expect(GameNightAudio.choices(gameNightActive: false) == AppSoundMode.allCases)
    }
}
