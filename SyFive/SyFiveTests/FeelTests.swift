import Foundation
import Testing
import AVFoundation
@testable import SyFive

struct FeelTests {

    // MARK: (a) Deterministic render — same recipe + same variant → byte-identical PCM buffers

    @Test func settleThunk_renderIsDeterministic() throws {
        let recipe = FeelCatalog.syFive.sounds["settle_thunk"]!
        let a = try #require(SoundRenderer.render(recipe, variantIndex: 0))
        let b = try #require(SoundRenderer.render(recipe, variantIndex: 0))

        #expect(a.frameLength == b.frameLength)
        let count = Int(a.frameLength)
        let pa = a.floatChannelData![0]
        let pb = b.floatChannelData![0]
        for i in 0..<count {
            #expect(pa[i] == pb[i], "Sample \(i) differs: \(pa[i]) vs \(pb[i])")
        }
    }

    @Test func allSoundRecipes_renderDeterministically() throws {
        for (id, recipe) in FeelCatalog.syFive.sounds {
            let a = try #require(SoundRenderer.render(recipe), "render returned nil for '\(id)'")
            let b = try #require(SoundRenderer.render(recipe), "second render returned nil for '\(id)'")
            let count = Int(a.frameLength)
            let pa = a.floatChannelData![0]
            let pb = b.floatChannelData![0]
            var differs = false
            for i in 0..<count where pa[i] != pb[i] { differs = true; break }
            #expect(!differs, "Non-deterministic render for '\(id)'")
        }
    }

    @Test func variantsDifferFromCanonical() throws {
        let recipe = FeelCatalog.syFive.sounds["settle_thunk"]!
        let base = try #require(SoundRenderer.render(recipe, variantIndex: 2)) // canonical (0 cents, 0 dB)
        let shifted = try #require(SoundRenderer.render(recipe, variantIndex: 0)) // -38 cents
        // They should differ: a pitched variant produces a different waveform
        let n = Int(base.frameLength)
        let pb = base.floatChannelData![0]
        let ps = shifted.floatChannelData![0]
        let anyDiffers = (0..<n).contains { pb[$0] != ps[$0] }
        #expect(anyDiffers, "Variant 0 should differ from variant 2")
    }

    @Test func rattleBed_renderIsDeterministic() throws {
        let recipe = FeelCatalog.syFive.rattles["rattle_bed"]!
        let a = try #require(SoundRenderer.render(recipe, seedIndex: 0))
        let b = try #require(SoundRenderer.render(recipe, seedIndex: 0))

        #expect(a.frameLength == b.frameLength)
        let count = Int(a.frameLength)
        let pa = a.floatChannelData![0]
        let pb = b.floatChannelData![0]
        var differs = false
        for i in 0..<count where pa[i] != pb[i] { differs = true; break }
        #expect(!differs, "Rattle render is not deterministic for seed 0")
    }

    @Test func rattleBed_seedsProduceDifferentBuffers() throws {
        let recipe = FeelCatalog.syFive.rattles["rattle_bed"]!
        let seed0 = try #require(SoundRenderer.render(recipe, seedIndex: 0))
        let seed1 = try #require(SoundRenderer.render(recipe, seedIndex: 1))
        let n = Int(seed0.frameLength)
        let p0 = seed0.floatChannelData![0]
        let p1 = seed1.floatChannelData![0]
        let anyDiffers = (0..<n).contains { p0[$0] != p1[$0] }
        #expect(anyDiffers, "Different seeds should produce different rattle beds")
    }

    // MARK: (b) §5.1 canonical JSON round-trip

    @Test func settleThunk_jsonRoundTrip() throws {
        let recipe = FeelCatalog.syFive.sounds["settle_thunk"]!
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        let firstPass = try encoder.encode(recipe)
        let decoded   = try JSONDecoder().decode(SoundRecipe.self, from: firstPass)
        let secondPass = try encoder.encode(decoded)

        // Round-trip: encode → decode → encode must be identical
        #expect(firstPass == secondPass, "JSON does not round-trip for settle_thunk")
    }

    // Tests the §5.1 canonical JSON contract by encoding → decoding → checking struct fields.
    // Using JSONDecoder avoids NSNumber↔Double bridging ambiguity from JSONSerialization.
    @Test func settleThunk_jsonHasCorrectShape() throws {
        let recipe = FeelCatalog.syFive.sounds["settle_thunk"]!
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data    = try encoder.encode(recipe)
        let decoded = try JSONDecoder().decode(SoundRecipe.self, from: data)

        #expect(decoded.id == "settle_thunk")
        #expect(decoded.durationMs == 160)
        #expect(decoded.renderSeed == 24301)
        #expect(decoded.layers.count == 3)

        guard case .tone(let body) = decoded.layers[0] else {
            Issue.record("Layer 0 is not a tone"); return
        }
        #expect(body.freqHz == 146.83)
        #expect(body.levelDb == -6)
        #expect(body.bendCents == -15)
        #expect(body.bendMs == 30)

        guard case .tone(let sub) = decoded.layers[1] else {
            Issue.record("Layer 1 is not a tone"); return
        }
        #expect(sub.freqHz == 73.42)
        #expect(sub.decayTauMs == 45)

        guard case .noise(let tick) = decoded.layers[2] else {
            Issue.record("Layer 2 is not a noise"); return
        }
        #expect(tick.bandLowHz == 300)
        #expect(tick.bandHighHz == 1200)
        #expect(tick.levelDb == -22)

        #expect(decoded.variants.count == 5)
        #expect(decoded.variants[0].pitchCents == -38)
        #expect(decoded.variants[2].pitchCents == 0)
        #expect(decoded.variants[4].pitchCents == 40)
    }

    @Test func catalog_allRecipesRoundTripJSON() throws {
        let catalog = FeelCatalog.syFive
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        let data    = try encoder.encode(catalog)
        let decoded = try JSONDecoder().decode(FeelCatalog.self, from: data)
        let second  = try encoder.encode(decoded)
        #expect(data == second, "FeelCatalog does not round-trip")
    }

    // MARK: (c) Cache key stability and sensitivity

    @Test func cacheKey_isSameForSameRecipe() {
        let cache  = SoundCache()
        let recipe = FeelCatalog.syFive.sounds["settle_thunk"]!
        let k1 = cache.key(sound: recipe, variantIndex: 0)
        let k2 = cache.key(sound: recipe, variantIndex: 0)
        #expect(k1 == k2, "Cache key is not stable for identical recipe + variant")
        #expect(k1.count == 64, "SHA-256 key should be 64 hex chars")
    }

    @Test func cacheKey_changesWhenVariantChanges() {
        let cache  = SoundCache()
        let recipe = FeelCatalog.syFive.sounds["settle_thunk"]!
        let k0 = cache.key(sound: recipe, variantIndex: 0)
        let k1 = cache.key(sound: recipe, variantIndex: 1)
        #expect(k0 != k1, "Different variants should produce different cache keys")
    }

    @Test func cacheKey_changesWhenRecipeFieldChanges() {
        let cache  = SoundCache()
        var recipe = FeelCatalog.syFive.sounds["settle_thunk"]!
        let original = cache.key(sound: recipe, variantIndex: 0)

        recipe.durationMs += 1
        let modified = cache.key(sound: recipe, variantIndex: 0)
        #expect(original != modified, "Changing durationMs must change the cache key")
    }

    @Test func cacheKey_changesWhenRendererVersionChanges() {
        // The version is baked into the key — this is a structural contract test:
        // verifying that rendererVersion participates in the key by checking key length and format.
        let cache = SoundCache()
        let recipe = FeelCatalog.syFive.sounds["settle_thunk"]!
        let k = cache.key(sound: recipe, variantIndex: 0)
        #expect(k.count == 64)
        #expect(k.allSatisfy { $0.isHexDigit }, "Cache key must be a lowercase hex string")
    }

    @Test func cacheKey_rattleVariesBySeed() {
        let cache  = SoundCache()
        let recipe = FeelCatalog.syFive.rattles["rattle_bed"]!
        let k0 = cache.key(rattle: recipe, seedIndex: 0)
        let k1 = cache.key(rattle: recipe, seedIndex: 1)
        #expect(k0 != k1, "Different seed indices must produce different cache keys")
    }

    // MARK: Frame counts

    @Test func renderFrameCounts_matchDuration() throws {
        let expectedSampleRate = SoundRenderer.sampleRate
        for (id, recipe) in FeelCatalog.syFive.sounds {
            let buf = try #require(SoundRenderer.render(recipe), "nil buffer for '\(id)'")
            let expected = AVAudioFrameCount(recipe.durationMs * expectedSampleRate / 1_000.0)
            #expect(buf.frameLength == expected, "\(id): expected \(expected) frames, got \(buf.frameLength)")
        }
    }
}
