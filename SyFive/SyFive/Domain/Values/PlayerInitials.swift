import Foundation

// First letter of each of the first two words, uppercased.
// Single-word names fall back to the first two characters.
func deriveInitials(from name: String) -> String {
    let words = name.split(separator: " ").map(String.init)
    if words.count >= 2 {
        return words.prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
    return String(name.prefix(2)).uppercased()
}
