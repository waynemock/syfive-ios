import SwiftUI

struct GameNightLogSheet: View {
    let matchID: UUID

    @Environment(\.dismiss) private var dismiss

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
                    Button {
                        UIPasteboard.general.string = content
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}
