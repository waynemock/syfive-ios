import Foundation
import AVFoundation

// Offline parametric renderer. All synthesis is arithmetic; no real-time DSP anywhere.
// Full catalog render is milliseconds; the cache (SoundCache) buys discipline and headroom,
// not launch speed — do not inline render paths into the audio graph.
struct SoundRenderer {

    // Bump ONLY when DSP math changes meaning (e.g. an envelope fix that changes the waveform).
    // Same recipe through a new version is a different sound; the cache key changes automatically.
    static let rendererVersion: Int = 1

    static let sampleRate: Double = 48_000
    static let format: AVAudioFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: 1,
        interleaved: false
    )!

    // MARK: - Public API

    static func render(_ recipe: SoundRecipe, variantIndex: Int = 0) -> AVAudioPCMBuffer? {
        let frameCount = Int(recipe.durationMs * sampleRate / 1_000.0)
        guard frameCount > 0 else { return nil }
        guard let buffer = makeBuffer(frames: frameCount) else { return nil }
        let out = buffer.floatChannelData![0]

        let (pitchMult, levelMult) = variantFactors(recipe, index: variantIndex)

        var noiseLayerIndex = 0
        for layer in recipe.layers {
            switch layer {
            case .tone(var t):
                t.freqHz *= pitchMult
                renderTone(t, into: out, count: frameCount)
            case .noise(var n):
                n.bandLowHz  *= pitchMult
                n.bandHighHz *= pitchMult
                // Each noise layer gets a distinct seed derived from the recipe seed.
                let seed = recipe.renderSeed ^ UInt64(noiseLayerIndex) &* 0x9E3779B97F4A7C15
                var rng = FeelLCG(seed: seed)
                renderNoise(n, rng: &rng, into: out, count: frameCount)
                noiseLayerIndex += 1
            }
        }

        if levelMult != 1.0 {
            for i in 0..<frameCount { out[i] *= Float(levelMult) }
        }

        #if DEBUG
        let peak = (0..<frameCount).reduce(0.0 as Float) { max($0, abs(out[$1])) }
        assert(peak <= 0.891,
               "SoundRenderer: '\(recipe.id)' peaks at \(String(format: "%.3f", peak)) — " +
               "exceeds −1 dBFS. Fix the recipe, not the renderer.")
        #endif

        return buffer
    }

    static func render(_ recipe: RattleRecipe, seedIndex: Int) -> AVAudioPCMBuffer? {
        guard seedIndex < recipe.seeds.count else { return nil }
        let frameCount = Int(recipe.durationMs * sampleRate / 1_000.0)
        guard frameCount > 0 else { return nil }
        guard let buffer = makeBuffer(frames: frameCount) else { return nil }
        let out = buffer.floatChannelData![0]

        var rng = FeelLCG(seed: recipe.seeds[seedIndex])
        let grainAmp = dbToAmp(recipe.grainLevelDb)
        let tailFadeStart = Int((recipe.durationMs - recipe.tailFadeMs) * sampleRate / 1_000.0)
        let bandCount = recipe.grainBandsHz.count

        // Inhomogeneous Poisson (thinning): draw from Poisson(λ_peak), accept at rate λ(t)/λ_peak.
        var t = 0.0
        let peakPerSample = recipe.densityPeakPerSec / sampleRate

        while true {
            // Inter-arrival from Exponential(λ_peak)
            let u1 = rng.nextDouble()
            t += -Foundation.log(max(u1, 1e-15)) / recipe.densityPeakPerSec
            if t * sampleRate >= Double(frameCount) { break }

            // Thinning acceptance
            let lambda = recipe.densityFloorPerSec +
                (recipe.densityPeakPerSec - recipe.densityFloorPerSec) *
                Foundation.exp(-t / recipe.densityTauSec)
            guard rng.nextDouble() < lambda / recipe.densityPeakPerSec else { continue }

            // Place grain
            let bandIdx  = Int(rng.next() % UInt64(bandCount))
            let jitter   = -rng.nextDouble() * abs(recipe.grainLevelJitterDb)
            let band     = recipe.grainBandsHz[bandIdx]
            let noise    = SoundRecipe.Noise(
                bandLowHz:    band[0],
                bandHighHz:   band[1],
                levelDb:      recipe.grainLevelDb + jitter,
                startMs:      t * 1_000.0,
                attackMs:     recipe.grainAttackMs,
                decayTauMs:   recipe.grainDecayTauMs
            )
            // Render this grain into a temporary slice, then add to output.
            let grainStart  = Int(t * sampleRate)
            let grainFrames = min(Int(recipe.grainDurMs * sampleRate / 1_000.0) + 1,
                                  frameCount - grainStart)
            if grainFrames > 0 {
                var grainRng = rng   // snapshot so grain noise is deterministic per event
                let adjustedNoise = SoundRecipe.Noise(
                    bandLowHz:  band[0],
                    bandHighHz: band[1],
                    levelDb:    recipe.grainLevelDb + jitter,
                    startMs:    0,
                    attackMs:   recipe.grainAttackMs,
                    decayTauMs: recipe.grainDecayTauMs
                )
                if let grainBuf = makeBuffer(frames: grainFrames) {
                    let gp = grainBuf.floatChannelData![0]
                    renderNoise(adjustedNoise, rng: &grainRng, into: gp, count: grainFrames)
                    for i in 0..<grainFrames { out[grainStart + i] += gp[i] }
                }
            }
            // Advance rng past grain's noise consumption (approximate — deterministic via snapshot above)
            _ = rng.next()
        }
        _ = peakPerSample // suppress unused-variable warning

        // Tail fade
        if tailFadeStart < frameCount {
            let fadeLen = frameCount - tailFadeStart
            for i in tailFadeStart..<frameCount {
                let fade = 1.0 - Float(i - tailFadeStart) / Float(fadeLen)
                out[i] *= fade
            }
        }

        return buffer
    }

    // MARK: - Private rendering primitives

    private static func renderTone(_ tone: SoundRecipe.Tone, into out: UnsafeMutablePointer<Float>, count: Int) {
        let amp        = dbToAmp(tone.levelDb)
        let startSamp  = Int(tone.startMs * sampleRate / 1_000.0)
        let attackSamp = max(1, Int(tone.attackMs * sampleRate / 1_000.0))
        let decayTau   = tone.decayTauMs / 1_000.0
        let bendEndSamp = tone.bendMs > 0 ? Int(tone.bendMs * sampleRate / 1_000.0) : 0
        var phase = 0.0

        for i in startSamp..<count {
            let local = i - startSamp
            // Instantaneous frequency with linear pitch bend
            let cents: Double
            if bendEndSamp > 0 {
                cents = tone.bendCents * min(1.0, Double(local) / Double(bendEndSamp))
            } else {
                cents = 0.0
            }
            let freq = tone.freqHz * pow(2.0, cents / 1_200.0)
            phase += 2.0 * .pi * freq / sampleRate

            // Envelope: linear attack then exponential decay
            let envelope: Double
            if local < attackSamp {
                envelope = Double(local) / Double(attackSamp)
            } else {
                let decayTime = Double(local - attackSamp) / sampleRate
                envelope = Foundation.exp(-decayTime / decayTau)
            }

            out[i] += Float(amp * envelope * sin(phase))
        }
    }

    private static func renderNoise(
        _ noise: SoundRecipe.Noise,
        rng: inout FeelLCG,
        into out: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        let amp        = dbToAmp(noise.levelDb)
        let startSamp  = Int(noise.startMs * sampleRate / 1_000.0)
        let attackSamp = max(1, Int(noise.attackMs * sampleRate / 1_000.0))
        let decayTau   = noise.decayTauMs / 1_000.0
        var filter     = BiquadBP(bandLowHz: noise.bandLowHz, bandHighHz: noise.bandHighHz)

        for i in startSamp..<count {
            let local   = i - startSamp
            let raw     = rng.nextDouble() * 2.0 - 1.0   // white noise in [−1, 1]
            let filtered = filter.process(raw)

            let envelope: Double
            if local < attackSamp {
                envelope = Double(local) / Double(attackSamp)
            } else {
                let decayTime = Double(local - attackSamp) / sampleRate
                envelope = Foundation.exp(-decayTime / decayTau)
            }

            out[i] += Float(amp * envelope * filtered)
        }
    }

    // MARK: - Helpers

    private static func makeBuffer(frames: Int) -> AVAudioPCMBuffer? {
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else { return nil }
        buf.frameLength = AVAudioFrameCount(frames)
        // Zero-fill (AVAudioPCMBuffer is not guaranteed zero on allocation)
        let ptr = buf.floatChannelData![0]
        for i in 0..<frames { ptr[i] = 0 }
        return buf
    }

    private static func variantFactors(_ recipe: SoundRecipe, index: Int) -> (pitch: Double, level: Double) {
        guard index < recipe.variants.count else { return (1.0, 1.0) }
        let v = recipe.variants[index]
        return (pow(2.0, v.pitchCents / 1_200.0), pow(10.0, v.levelDb / 20.0))
    }

    static func dbToAmp(_ db: Double) -> Double {
        pow(10.0, db / 20.0)
    }
}

// MARK: - RBJ band-pass biquad filter

private struct BiquadBP {
    let b0, b2, a1, a2: Double   // b1 = 0 for constant-skirt band-pass
    var x1 = 0.0, x2 = 0.0
    var y1 = 0.0, y2 = 0.0

    init(bandLowHz: Double, bandHighHz: Double) {
        let f0  = (bandLowHz * bandHighHz).squareRoot()
        let bw  = max(bandHighHz - bandLowHz, 1.0)
        let Q   = f0 / bw
        let w0  = 2.0 * .pi * f0 / SoundRenderer.sampleRate
        let α   = sin(w0) / (2.0 * Q)
        let a0  = 1.0 + α
        b0  =  α / a0
        b2  = -α / a0
        a1  = -2.0 * cos(w0) / a0
        a2  = (1.0 - α) / a0
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1;  x1 = x
        y2 = y1;  y1 = y
        return y
    }
}

// MARK: - LCG (algorithm copied from DiceRandSource; no import from Dice/ — D-053)

struct FeelLCG {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        // Knuth multiplicative LCG
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }

    mutating func nextDouble() -> Double {
        Double(next()) / Double(UInt64.max)
    }
}
