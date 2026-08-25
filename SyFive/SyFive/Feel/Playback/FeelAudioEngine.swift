import Foundation
import AVFoundation
import SyLibCore

// AVAudioEngine wrapper for the Feel system.
// 8 pooled one-shot nodes (round-robin, steal-oldest) + 1 dedicated bed node.
// Only scheduleBuffer + play on the hot path — no runtime pitch/rate units.
final class FeelAudioEngine {

    private let engine = AVAudioEngine()
    private let oneShots: [AVAudioPlayerNode]
    private let bedNode = AVAudioPlayerNode()
    private var nextOneShotIndex = 0
    private(set) var isStarted = false
    private let logger = AppLogger(category: "FeelAudioEngine")

    private var loadedBuffers: [String: AVAudioPCMBuffer] = [:]
    private(set) var currentBedVolume: Float = 0

    var interruptionBegan: (() -> Void)?
    var interruptionEnded: (() -> Void)?

    init() {
        oneShots = (0..<8).map { _ in AVAudioPlayerNode() }
        attachAndConnect()
        subscribeToInterruptions()
    }

    // MARK: - Setup

    private func attachAndConnect() {
        for node in oneShots { engine.attach(node) }
        engine.attach(bedNode)
        let mixer = engine.mainMixerNode
        let format = SoundRenderer.format
        for node in oneShots { engine.connect(node, to: mixer, format: format) }
        engine.connect(bedNode, to: mixer, format: format)
        mixer.outputVolume = 0.63   // −4 dB master trim per §6.1
    }

    private func subscribeToInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            stopBed()
            interruptionBegan?()
        case .ended:
            // Re-prepare session; everything is one-shot so there's nothing to resume.
            isStarted = false   // forces lazy restart on next play call
            interruptionEnded?()
        @unknown default: break
        }
    }

    // MARK: - Session + engine lifecycle

    private var currentMode: AppSoundMode = .mix

    /// Called when the user changes the sound mode setting. Updates the audio session
    /// category so that subsequent sounds use the correct mixing behaviour.
    func applyMode(_ mode: AppSoundMode) {
        currentMode = mode
        applySessionCategory()
        if isStarted { try? AVAudioSession.sharedInstance().setActive(true) }
    }

    private func applySessionCategory() {
        let session = AVAudioSession.sharedInstance()
        switch currentMode {
        case .off, .mix:
            // .ambient + .mixWithOthers: respects silent switch, mixes with podcasts/music.
            try? session.setCategory(.ambient, mode: .default, options: .mixWithOthers)
        case .exclusive:
            // .soloAmbient: respects silent switch, ducks other audio (podcasts pause).
            try? session.setCategory(.soloAmbient, mode: .default, options: [])
        }
    }

    private func configureSession() {
        applySessionCategory()
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func ensureStarted() {
        guard !isStarted else { return }
        configureSession()
        do {
            try engine.start()
            isStarted = true
        } catch {
            // Silent failure — failed engine → feel goes silent, never alert (§2.2, §6.1).
            logger.warning(self, "engine start failed: \(error)")
        }
    }

    func stopForBackground() { stopBed() }

    // MARK: - One-shot playback

    func play(key: String) {
        guard let buffer = loadedBuffers[key] else { return }
        playBuffer(buffer)
    }

    func playBuffer(_ buffer: AVAudioPCMBuffer) {
        ensureStarted()
        guard isStarted else { return }
        let node = nextOneShot()
        node.scheduleBuffer(buffer, completionHandler: nil)
        if !node.isPlaying { node.play() }
    }

    // MARK: - Rattle bed

    func startBed(key: String, volume: Float) {
        guard let buffer = loadedBuffers[key] else { return }
        ensureStarted()
        guard isStarted else { return }
        bedNode.volume = volume
        currentBedVolume = volume
        bedNode.scheduleBuffer(buffer, completionHandler: nil)
        if !bedNode.isPlaying { bedNode.play() }
    }

    func duckBed(factor: Float = 0.65) {
        currentBedVolume *= factor
        bedNode.volume = currentBedVolume
    }

    func killBed(fadeDurationMs: Double = 80) {
        let startVolume = currentBedVolume
        let steps = max(2, Int(fadeDurationMs / 10.0))
        let interval = fadeDurationMs / 1_000.0 / Double(steps)

        for step in 1...steps {
            let delay = Double(step) * interval
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                let t = Float(step) / Float(steps)
                let vol = startVolume * (1.0 - t)
                self.bedNode.volume = vol
                if step == steps {
                    self.bedNode.stop()
                    self.currentBedVolume = 0
                }
            }
        }
    }

    private func stopBed() {
        bedNode.stop()
        currentBedVolume = 0
    }

    // MARK: - Buffer management

    func loadBuffer(_ buffer: AVAudioPCMBuffer, forKey key: String) {
        loadedBuffers[key] = buffer
    }

    // MARK: - Private

    private func nextOneShot() -> AVAudioPlayerNode {
        let node = oneShots[nextOneShotIndex]
        nextOneShotIndex = (nextOneShotIndex + 1) % oneShots.count
        // If the chosen node's queue is exhausted (buffer done), its isPlaying may
        // still be true. scheduleBuffer queues behind the current; the steal-oldest
        // behavior ensures old audio is displaced.
        return node
    }
}
