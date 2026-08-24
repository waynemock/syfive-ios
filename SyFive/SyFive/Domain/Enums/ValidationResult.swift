import Foundation

enum ValidationResult: Sendable {
    case valid
    case invalid(reason: String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}
