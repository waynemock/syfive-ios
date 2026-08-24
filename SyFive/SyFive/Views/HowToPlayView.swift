import SwiftUI

struct HowToPlayView: View {
    var settings: AppSettingsModel?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var showsDismissAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Spacer().frame(height: 8)

                        contentBlock(title: "How to Play") {
                            VStack(alignment: .leading, spacing: 6) {
                                bulletRow("Roll the dice — up to three times a turn.")
                                bulletRow("Hold the ones you want to keep.")
                                bulletRow("When you're happy, score them in a category.")
                                bulletRow("Each category is used once. Fill all thirteen to finish.")
                                bulletRow("Highest total wins.")
                            }
                        }

                        contentBlock(title: "The upper bonus") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Score 63 or more across Ones through Sixes and you earn an extra 35 points.")
                                Text("Three of each number gets you there.")
                            }
                        }

                        contentBlock(title: "Taking a zero") {
                            Text("Sometimes nothing fits. You can score any open category as a zero — it's a normal move, and sometimes the right one.")
                        }

                        contentBlock(title: "Rolling another Yatzy") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Once you've scored your first Yatzy for 50 points, every extra five-of-a-kind you roll earns a 100-point bonus.")
                                Text("When you roll one, it first goes to the matching number in the upper section, if that box is still open. If it's already taken, place the roll in any open category and score its full value.")
                                Text("One exception: if you scored your first Yatzy as a zero, every five-of-a-kind after that counts as an ordinary roll — no bonus and no special placement.")
                            }
                        }
                        categoriesBlock

                        if settings?.helpDismissed != true {
                            Button {
                                showsDismissAlert = true
                            } label: {
                                Text("Got it, hide this")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.primaryAccent)
                            }
                            .padding(.top, 4)
                        }

                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Hide the help button?", isPresented: $showsDismissAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Hide") {
                    settings?.helpDismissed = true
                    dismiss()
                }
            } message: {
                Text("How to Play stays in the Menu, in the last section with About. You can open it any time.")
            }
        }
    }

    // MARK: - Content Blocks

    @ViewBuilder
    private func contentBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(theme.primaryAccent)
                .accessibilityAddTraits(.isHeader)
            content()
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    private var categoriesBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The categories")
                .font(.title3.bold())
                .foregroundStyle(theme.primaryAccent)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 6) {
                Text("Upper")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.secondaryAccent)
                    .accessibilityAddTraits(.isHeader)
                categoryRow(name: "Ones – Sixes", description: "Count that number and add them up.")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Lower")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.secondaryAccent)
                    .accessibilityAddTraits(.isHeader)
                categoryRow(name: "Three of a Kind", description: "Three matching. Score the total of all five dice.")
                categoryRow(name: "Four of a Kind", description: "Four matching. Score the total of all five dice.")
                categoryRow(name: "Full House", description: "Three of one, two of another. 25 points.")
                categoryRow(name: "Small Straight", description: "Four in a row. 30 points.")
                categoryRow(name: "Large Straight", description: "Five in a row. 40 points.")
                categoryRow(name: "Yatzy", description: "All five matching. 50 points.")
                categoryRow(name: "Chance", description: "Anything at all. Score the total of all five dice.")
            }
        }
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }

    private func categoryRow(name: String, description: String) -> some View {
        (Text(name).bold() + Text(" — ") + Text(description))
            .font(.body)
            .foregroundStyle(.primary)
    }
}

#Preview("Dark") {
    HowToPlayView()
        .environment(\.theme, Theme(type: .midnight, colorScheme: .dark))
}

#Preview("Light") {
    HowToPlayView()
        .environment(\.theme, Theme(type: .midnight, colorScheme: .light))
}
