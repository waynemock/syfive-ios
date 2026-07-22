import Foundation
import AVFoundation

// Content-addressed buffer cache. Key = SHA-256(canonicalJSON ‖ rendererVersion ‖ formatTag ‖ selector).
// Stored in Library/Caches/Feel/ as CAF/Float32/48kHz/mono files.
// Purge by the OS is safe: same catalog + same renderer version → byte-identical rebuild on next launch.
final class SoundCache: @unchecked Sendable {

    private static let formatTag = "caf-f32-48k-mono"
    private static let subdirectory = "Feel"

    private let cacheDir: URL

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDir = base.appendingPathComponent(Self.subdirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Key generation

    func key(sound recipe: SoundRecipe, variantIndex: Int) -> String {
        let selector = "\(variantIndex)"
        return computeKey(encodable: recipe, selector: selector)
    }

    func key(rattle recipe: RattleRecipe, seedIndex: Int) -> String {
        let selector = String(recipe.seeds[seedIndex], radix: 16, uppercase: false)
        return computeKey(encodable: recipe, selector: selector)
    }

    // MARK: - Load / store

    func load(key: String) -> AVAudioPCMBuffer? {
        let url = cacheDir.appendingPathComponent("\(key).caf")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: SoundRenderer.format,
                                            frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        try? file.read(into: buffer)
        return buffer
    }

    func store(_ buffer: AVAudioPCMBuffer, key: String) {
        let url = cacheDir.appendingPathComponent("\(key).caf")
        let settings: [String: Any] = [
            AVFormatIDKey:              kAudioFormatLinearPCM,
            AVSampleRateKey:            SoundRenderer.sampleRate,
            AVNumberOfChannelsKey:      1,
            AVLinearPCMBitDepthKey:     32,
            AVLinearPCMIsFloatKey:      true,
            AVLinearPCMIsNonInterleaved: true,
        ]
        guard let file = try? AVAudioFile(forWriting: url,
                                           settings: settings,
                                           commonFormat: .pcmFormatFloat32,
                                           interleaved: false) else { return }
        try? file.write(from: buffer)
    }

    // Removes any .caf files in the Feel directory whose names are not in liveKeys.
    func sweepStale(liveKeys: Set<String>) {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: cacheDir,
                                                                           includingPropertiesForKeys: nil) else { return }
        for url in contents where url.pathExtension == "caf" {
            let name = url.deletingPathExtension().lastPathComponent
            if !liveKeys.contains(name) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Private

    private func computeKey<T: Codable>(encodable: T, selector: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let recipeJSON = try? encoder.encode(encodable) else { return "" }

        var raw = [UInt8](recipeJSON)
        raw.append(contentsOf: "\(SoundRenderer.rendererVersion)".utf8)
        raw.append(contentsOf: Self.formatTag.utf8)
        raw.append(contentsOf: selector.utf8)

        return sha256(raw)
    }
}

// MARK: - SHA-256 (pure Swift; no CryptoKit — import rule D-053: Foundation + AVFoundation + CoreHaptics only)

private func sha256(_ bytes: [UInt8]) -> String {
    var h: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ]
    let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]

    // Pre-processing: padding
    var msg = bytes
    let origLen = msg.count
    msg.append(0x80)
    while msg.count % 64 != 56 { msg.append(0) }
    var bitLen = UInt64(origLen) * 8
    for _ in stride(from: 7, through: 0, by: -1) {
        msg.append(UInt8(bitLen & 0xff))
        bitLen >>= 8
    }
    // Fix: bit length must be big-endian — re-append correctly
    msg.removeLast(8)
    bitLen = UInt64(origLen) * 8
    for i in (0..<8).reversed() { msg.append(UInt8((bitLen >> (i * 8)) & 0xff)) }

    // Process 64-byte blocks
    for chunkStart in stride(from: 0, to: msg.count, by: 64) {
        var w = [UInt32](repeating: 0, count: 64)
        for i in 0..<16 {
            let b = chunkStart + i * 4
            w[i] = UInt32(msg[b]) << 24 | UInt32(msg[b+1]) << 16 |
                   UInt32(msg[b+2]) << 8  | UInt32(msg[b+3])
        }
        for i in 16..<64 {
            let s0 = rotr(w[i-15], 7) ^ rotr(w[i-15], 18) ^ (w[i-15] >> 3)
            let s1 = rotr(w[i-2], 17) ^ rotr(w[i-2], 19)  ^ (w[i-2]  >> 10)
            w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
        }
        var (a, b, c, d, e, f, g, hv) = (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7])
        for i in 0..<64 {
            let S1   = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
            let ch   = (e & f) ^ (~e & g)
            let t1   = hv &+ S1 &+ ch &+ k[i] &+ w[i]
            let S0   = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
            let maj  = (a & b) ^ (a & c) ^ (b & c)
            let t2   = S0 &+ maj
            hv = g; g = f; f = e; e = d &+ t1
            d  = c; c = b; b = a; a = t1 &+ t2
        }
        h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d
        h[4] = h[4] &+ e; h[5] = h[5] &+ f; h[6] = h[6] &+ g; h[7] = h[7] &+ hv
    }
    return h.map { String(format: "%08x", $0) }.joined()
}

@inline(__always)
private func rotr(_ x: UInt32, _ n: Int) -> UInt32 { (x >> n) | (x << (32 - n)) }
