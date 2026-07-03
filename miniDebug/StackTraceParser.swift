import Foundation

class StackTraceParser {
    static let shared = StackTraceParser()
    private init() {}

    func parse(message: String, type: ErrorType, rawStack: String, projectPath: String) -> ErrorDetail {
        let frames = extractFrames(from: rawStack)

        // If no frames found in the raw stack, try to find a frame in the error message itself
        let finalFrames = frames.isEmpty ? extractFrames(from: message) : frames

        return ErrorDetail(
            type: type,
            message: message,
            frames: finalFrames,
            snippet: nil,
            diagnosis: nil,
            rawStackTrace: rawStack
        )
    }

    func extractFrames(from text: String) -> [StackFrame] {
        var frames: [StackFrame] = []

        // Pattern 1: Standard JS / Hermes (at path/to/file.js:line:col)
        let standardRegex = "at\\s+([^\\s)]+):(\\d+):(\\d+)"

        // Pattern 2: Alternative JS (at path/to/file.js (line:col))
        let altRegex = "at\\s+([^\\s)]+)\\s+\\((?:line\\s*)?(\\d+):(\\d+)\\)"

        // Pattern 3: C-style/Native errors (path/to/file.swift:line:col: error:)
        let nativeRegex = "([^\\s]+):(\\d+):(\\d+):"

        // Pattern 4: React component stack (at ComponentName (path/URL:line:col))
        // e.g. "at TimerScreen (http://localhost:8081/index.bundle//&...:100031:69)"
        // Distinct from Pattern 2 because the parens wrap a full path/URL + line:col,
        // not just bare "(line:col)".
        let componentStackRegex = "at\\s+[^\\s(]+\\s*\\(([^()\\s]+):(\\d+):(\\d+)\\)"

        let combinedPatterns = [standardRegex, altRegex, nativeRegex, componentStackRegex]

        for pattern in combinedPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
                let matches = regex.matches(in: text, options: [], range: nsRange)

                for match in matches {
                    if match.numberOfRanges >= 4 {
                        let fileRange = Range(match.range(at: 1), in: text)!
                        let lineRange = Range(match.range(at: 2), in: text)!
                        let colRange = Range(match.range(at: 3), in: text)!

                        let fileName = String(text[fileRange])
                        let line = Int(text[lineRange]) ?? 0
                        let col = Int(text[colRange]) ?? 0

                        frames.append(StackFrame(
                            fileName: fileName,
                            line: line,
                            column: col,
                            functionName: nil,
                            isExternal: fileName.contains("node_modules") || fileName.contains("react-native") || fileName.contains("/Developer/")
                        ))
                    }
                }
            } catch {
                print("Parsing error: \(error)")
            }
        }

        return frames
    }
}
