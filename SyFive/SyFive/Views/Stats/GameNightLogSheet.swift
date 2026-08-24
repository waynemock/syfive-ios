import SwiftUI

struct GameNightLogSheet: View {
    let matchID: UUID

    @Environment(\.dismiss) private var dismiss

    private var logFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("gnlogs")
            .appendingPathComponent("\(matchID.uuidString).log")
    }

    private var content: String {
        GameNightLogBuffer.shared.logContent(for: matchID)
    }

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Text(content)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .navigationTitle("GN Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: logFileURL,
                        preview: SharePreview(
                            "\(matchID.uuidString.prefix(8)).log",
                            image: Image(systemName: "doc.text")
                        )
                    )
                }
            }
        }
    }
}
