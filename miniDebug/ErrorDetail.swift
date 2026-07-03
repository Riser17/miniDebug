import Foundation

enum ErrorType: String, CaseIterable {
    case importError = "Import/Module Error"
    case runtimeError = "Runtime Error"
    case syntaxError = "Syntax/TypeScript Error"
    case nativeError = "Native Module Error"
    case hookError = "React Hook Violation"
    case navError = "Navigation Error"
    case unknown = "Unknown Error"
}

struct StackFrame: Identifiable, Equatable {
    let id = UUID()
    let fileName: String
    let line: Int
    let column: Int
    let functionName: String?
    let isExternal: Bool // True if in node_modules or core libraries
}

struct AIDiagnosis {
    let rootCause: String
    let suggestedFix: String
    let confidence: ConfidenceLevel
    let references: [String]

    enum ConfidenceLevel: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
}

struct ErrorDetail: Identifiable {
    let id = UUID()
    let type: ErrorType
    let message: String
    var frames: [StackFrame]
    var snippet: String?
    var diagnosis: AIDiagnosis?
    let rawStackTrace: String
    let timestamp = Date()
}
