import SwiftUI
import UIKit

struct AddVoicesSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(icon: String, text: String)] = [
        ("gearshape",       "Open the Settings app on your device."),
        ("figure.walk",     "Tap Accessibility."),
        ("speaker.wave.2",  "Tap Spoken Content, then Voices."),
        ("arrow.down.circle", "Choose a language and download an Enhanced or Premium voice.")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 16) {
                                Text("\(index + 1)")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22, alignment: .trailing)
                                    .padding(.top, 1)
                                HStack(spacing: 10) {
                                    Image(systemName: step.icon)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    Text(step.text)
                                        .font(.body)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("How to add voices")
                    } footer: {
                        Text("Opening Settings will land on this app's page. Follow the steps above from there. After returning, the Voice list will reflect any newly downloaded voices.")
                            .font(.footnote)
                    }
                }

                Divider()

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Add More Voices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AddVoicesSheet()
}
