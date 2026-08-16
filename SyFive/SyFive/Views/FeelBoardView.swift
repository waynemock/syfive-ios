import SwiftUI

// Debug feel board — App layer, SwiftUI, never extracted (§9).
// Gate: AppConfig.DebugFeel.showFeelBoard
// Sliders bind to working copies of catalog entries; audition renders in-memory,
// bypassing the cache. Freeze prints canonical JSON to console + pasteboard.
struct FeelBoardView: View {
    @Environment(FeelDirector.self) private var director
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var workingSounds: [String: SoundRecipe]
    @State private var workingHaptics: [String: HapticRecipe]
    @State private var useEdited: [String: Bool] = [:]
    @State private var expandedEvent: String?

    private let logger = AppLogger(category: "FeelBoardView")

    private static let eventOrder = [
        "settle_thunk", "hold_engage", "hold_release",
        "die_nudge", "die_reroll", "score_confirm",
        "yatzy_moment", "game_end", "undo",
    ]
    private static let rattleOrder = ["rattle_bed"]

    init() {
        let c = FeelCatalog.syFive
        _workingSounds  = State(initialValue: c.sounds)
        _workingHaptics = State(initialValue: c.haptics)
    }

    var body: some View {
        NavigationStack {
            List {
                masterSection
                ForEach(Self.eventOrder, id: \.self) { id in
                    eventSection(id: id)
                }
                ForEach(Self.rattleOrder, id: \.self) { id in
                    rattleSection(id: id)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Feel Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Master toggles

    private var masterSection: some View {
        Section {
            HStack {
                Label("Sound",   systemImage: "speaker.wave.2")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { director.soundEnabled },
                    set: { director.soundMode = $0 ? .mix : .off }
                ))
            }
            HStack {
                Label("Haptics", systemImage: "hand.tap")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { director.hapticsEnabled },
                    set: { director.hapticsEnabled = $0 }
                ))
            }
            if !director.hapticSupported {
                Text("Haptics not supported on this device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Master")
                .foregroundStyle(theme.primaryAccent)
        }
    }

    // MARK: - Sound event section

    @ViewBuilder
    private func eventSection(id: String) -> some View {
        let isExpanded = expandedEvent == id
        let edited = useEdited[id] ?? false

        Section {
            // Header row + expand toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedEvent = isExpanded ? nil : id
                }
            } label: {
                HStack {
                    Text(id)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                // A/B toggle
                if workingSounds[id] != nil {
                    Toggle("Use edited", isOn: Binding(
                        get: { useEdited[id] ?? false },
                        set: { useEdited[id] = $0 }
                    ))
                    .font(.caption)
                }

                // Layer editors
                if let recipe = workingSounds[id] {
                    soundEditor(id: id, recipe: Binding(
                        get: { workingSounds[id] ?? recipe },
                        set: { workingSounds[id] = $0 }
                    ))
                }

                // Haptic editor
                if workingHaptics[id] != nil {
                    hapticEditor(id: id)
                }
            }

            // Audition buttons
            HStack(spacing: 12) {
                AuditionButton("Sound") {
                    let r = (edited ? workingSounds[id] : FeelCatalog.syFive.sounds[id]) ?? FeelCatalog.syFive.sounds[id]!
                    director.auditionSound(r)
                }
                .disabled(workingSounds[id] == nil)

                AuditionButton("Haptic") {
                    let r = (edited ? workingHaptics[id] : FeelCatalog.syFive.haptics[id]) ?? FeelCatalog.syFive.haptics[id]!
                    director.auditionHaptic(r)
                }
                .disabled(workingHaptics[id] == nil || !director.hapticSupported)

                AuditionButton("Both") {
                    if let s = (edited ? workingSounds[id] : FeelCatalog.syFive.sounds[id]) {
                        director.auditionSound(s)
                    }
                    if let h = (edited ? workingHaptics[id] : FeelCatalog.syFive.haptics[id]) {
                        director.auditionHaptic(h)
                    }
                }
                .disabled(workingSounds[id] == nil && workingHaptics[id] == nil)
            }
            .padding(.vertical, 4)

            // Freeze
            if workingSounds[id] != nil {
                Button("Freeze sound JSON") { freezeSound(id: id) }
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Rattle section

    @ViewBuilder
    private func rattleSection(id: String) -> some View {
        Section {
            Text(id).font(.headline)
            AuditionButton("Sound") {
                // Rattle: use seed 0 for audition
                if let recipe = FeelCatalog.syFive.rattles[id],
                   SoundRenderer.render(recipe, seedIndex: 0) != nil {
                    // director has no dedicated rattle audition yet — play via buffer
                    director.rollStarted(unheldCount: 5)
                }
            }
        }
    }

    // MARK: - Sound recipe editor

    @ViewBuilder
    private func soundEditor(id: String, recipe: Binding<SoundRecipe>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledSlider("Duration", value: recipe.durationMs, in: 30...2000, format: "%.0f ms")
            ForEach(Array(recipe.wrappedValue.layers.indices), id: \.self) { idx in
                layerEditorRow(idx: idx, recipe: recipe)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func layerEditorRow(idx: Int, recipe: Binding<SoundRecipe>) -> some View {
        let layer = recipe.wrappedValue.layers[idx]
        switch layer {
        case .tone:
            Text("Tone \(idx)").font(.caption.bold()).foregroundStyle(.secondary)
            toneEditor(Binding(
                get: {
                    guard case .tone(let t) = recipe.wrappedValue.layers[idx] else {
                        return SoundRecipe.Tone(freqHz: 0, levelDb: 0, attackMs: 0, decayTauMs: 0)
                    }
                    return t
                },
                set: { recipe.wrappedValue.layers[idx] = .tone($0) }
            ))
        case .noise:
            Text("Noise \(idx)").font(.caption.bold()).foregroundStyle(.secondary)
            noiseEditor(Binding(
                get: {
                    guard case .noise(let n) = recipe.wrappedValue.layers[idx] else {
                        return SoundRecipe.Noise(bandLowHz: 0, bandHighHz: 0, levelDb: 0, attackMs: 0, decayTauMs: 0)
                    }
                    return n
                },
                set: { recipe.wrappedValue.layers[idx] = .noise($0) }
            ))
        }
    }

    @ViewBuilder
    private func toneEditor(_ tone: Binding<SoundRecipe.Tone>) -> some View {
        LabeledSlider("freq",     value: tone.freqHz,     in: 50...2000,   format: "%.1f Hz")
        LabeledSlider("level",    value: tone.levelDb,    in: -40...0,     format: "%.1f dB")
        LabeledSlider("attack",   value: tone.attackMs,   in: 0.5...50,    format: "%.1f ms")
        LabeledSlider("decay τ",  value: tone.decayTauMs, in: 1...600,     format: "%.0f ms")
        LabeledSlider("bend ¢",   value: tone.bendCents,  in: -100...100,  format: "%.0f ¢")
        LabeledSlider("bend ms",  value: tone.bendMs,     in: 0...200,     format: "%.0f ms")
    }

    @ViewBuilder
    private func noiseEditor(_ noise: Binding<SoundRecipe.Noise>) -> some View {
        LabeledSlider("lo Hz",   value: noise.bandLowHz,   in: 50...5000,   format: "%.0f Hz")
        LabeledSlider("hi Hz",   value: noise.bandHighHz,  in: 100...10000, format: "%.0f Hz")
        LabeledSlider("level",   value: noise.levelDb,     in: -40...0,     format: "%.1f dB")
        LabeledSlider("attack",  value: noise.attackMs,    in: 0.5...20,    format: "%.1f ms")
        LabeledSlider("decay τ", value: noise.decayTauMs,  in: 0.5...50,    format: "%.1f ms")
    }

    // MARK: - Haptic editor

    @ViewBuilder
    private func hapticEditor(id: String) -> some View {
        if let recipe = workingHaptics[id] {
            VStack(alignment: .leading, spacing: 4) {
                Text("Haptic").font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(Array(recipe.events.enumerated()), id: \.offset) { idx, event in
                    let intensityBinding = Binding<Double>(
                        get: { workingHaptics[id]?.events[idx].intensity ?? 0 },
                        set: { workingHaptics[id]?.events[idx].intensity = $0 }
                    )
                    let sharpnessBinding = Binding<Double>(
                        get: { workingHaptics[id]?.events[idx].sharpness ?? 0 },
                        set: { workingHaptics[id]?.events[idx].sharpness = $0 }
                    )
                    HStack {
                        Text("[\(idx)] \(event.kind.rawValue) @\(String(format: "%.0f", event.timeMs))ms")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    LabeledSlider("I", value: intensityBinding, in: 0...1, format: "%.2f")
                    LabeledSlider("S", value: sharpnessBinding, in: 0...1, format: "%.2f")
                }
            }
        }
    }

    // MARK: - Freeze

    private func freezeSound(id: String) {
        guard let recipe = workingSounds[id] else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        guard let data = try? encoder.encode(recipe),
              let json = String(data: data, encoding: .utf8) else { return }
        logger.debug(self, "FREEZE \(id):\n\(json)")
        UIPasteboard.general.string = json
    }
}

// MARK: - Helper views

private struct AuditionButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String

    init(_ label: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String) {
        self.label = label
        self._value = value
        self.range = range
        self.format = format
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Slider(value: $value, in: range)
            Text(String(format: format, value))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
    }
}

#Preview {
    FeelBoardView()
        .environment(FeelDirector())
}
