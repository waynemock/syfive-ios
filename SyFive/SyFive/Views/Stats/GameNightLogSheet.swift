import SwiftUI
import SyLibGameNight

struct GameNightLogSheet: View {
    private let title: String
    private let content: String
    private let shareURL: URL?

    init(matchID: UUID) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("gnlogs")
            .appendingPathComponent("\(matchID.uuidString).log")
        self.title = "\(matchID.uuidString.prefix(8)).log"
        self.content = GameNightLogBuffer.shared.logContent(for: matchID)
        self.shareURL = url
    }

    init(title: String, content: String) {
        self.title = title
        self.content = content
        self.shareURL = nil
    }

    @Environment(\.dismiss) private var dismiss

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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                if let url = shareURL {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                            item: url,
                            preview: SharePreview(
                                title,
                                image: Image(systemName: "doc.text")
                            )
                        )
                    }
                }
            }
        }
    }
}
