import Foundation

class ErrorDetector {
    static let shared = ErrorDetector()
    private init() {}

    struct ErrorPattern {
        let type: ErrorType
        let regex: String
        let messageGroup: Int
    }

    private let patterns: [ErrorPattern] = [
        // 1. High Priority: Specific JS/TS Errors
        ErrorPattern(type: .importError, regex: "Unable to resolve module [\"']([^\"']+)[\"']", messageGroup: 1),
        ErrorPattern(type: .importError, regex: "Cannot find module [\"']([^\"']+)[\"']", messageGroup: 1),
        ErrorPattern(type: .importError, regex: "Unable to resolve module ([^\\s\\n]+)", messageGroup: 1),

        // Bracketed style, e.g. "{ [ReferenceError: Property 'X' doesn't exist] ... }"
        // Covers every standard JS error constructor.
        ErrorPattern(type: .runtimeError, regex: "\\[(TypeError|ReferenceError|RangeError|SyntaxError|URIError|AggregateError|EvalError|Error): ([^\\]\\n]+)\\]", messageGroup: 2),

        ErrorPattern(type: .syntaxError, regex: "TS\\d+: ([^\\n]+)", messageGroup: 1),
        ErrorPattern(type: .syntaxError, regex: "Property '([^']+)' (does not|doesn't) exist", messageGroup: 1),
        ErrorPattern(type: .syntaxError, regex: "Render Error: ([^\\n]+)", messageGroup: 1),
        ErrorPattern(type: .syntaxError, regex: "SyntaxError: ([^\\n]+)", messageGroup: 1),

        // Plain "TypeName: message" style, one alternative per built-in JS error type.
        ErrorPattern(type: .runtimeError, regex: "(TypeError|ReferenceError|RangeError|URIError|AggregateError|EvalError): ([^\\n]+)", messageGroup: 2),

        // Generic catch-all "Error: message" (must stay last among JS error patterns
        // so the more specific types above get first crack at matching).
        ErrorPattern(type: .runtimeError, regex: "Error: ([^\\n]+)", messageGroup: 1),

        // 2. React Specific Errors
        ErrorPattern(type: .hookError, regex: "(Invalid hook call|Too many re-renders)", messageGroup: 0),
        ErrorPattern(type: .navError, regex: "The action \"([^\"]+)\" with payload is dispatched", messageGroup: 0),

        // 3. Native/System Errors
        ErrorPattern(type: .nativeError, regex: "FATAL EXCEPTION: ([^\\n]+)", messageGroup: 1),
        ErrorPattern(type: .nativeError, regex: "\\*\\*\\* uncaught exception ([^\\n]+)", messageGroup: 1),
        ErrorPattern(type: .nativeError, regex: "error: ([^\\n]+)", messageGroup: 1),
        ErrorPattern(type: .nativeError, regex: "Failed to build ([^\\n]+)", messageGroup: 1),
        ErrorPattern(type: .nativeError, regex: "exited with error code '(\\d+)'", messageGroup: 1),
        ErrorPattern(type: .nativeError, regex: "^error\\s+([^\\n]+)", messageGroup: 1)
    ]

    func detect(text: String) -> (type: ErrorType, message: String)? {
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern.regex, options: [.caseInsensitive])
                let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)

                if let match = regex.firstMatch(in: text, options: [], range: nsRange) {
                    if pattern.messageGroup != 0 && match.numberOfRanges > pattern.messageGroup {
                        let groupRange = match.range(at: pattern.messageGroup)
                        if let range = Range(groupRange, in: text) {
                            return (pattern.type, String(text[range]))
                        }
                    }

                    let fullRange = match.range(at: 0)
                    if let range = Range(fullRange, in: text) {
                        return (pattern.type, String(text[range]))
                    }
                }
            } catch {
                print("Regex error: \(error)")
            }
        }
        return nil
    }

    private func extractGroup(text: String, group: Int) -> String? {
        // This method is now redundant as logic is integrated into detect()
        return nil
    }
}
