import Foundation

class CodeSnippetService {
    static let shared = CodeSnippetService()
    private init() {}

    func getSnippet(for filePath: String, line: Int, window: Int = 5) -> String? {
        let expandedPath = (filePath as NSString).expandingTildeInPath

        do {
            let content = try String(contentsOfFile: expandedPath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            guard line > 0 && line <= lines.count else { return nil }

            let start = max(0, line - 1 - window)
            let end = min(lines.count - 1, line - 1 + window)

            var snippet = ""
            for i in start...end {
                let lineNum = i + 1
                let prefix = lineNum == line ? "▶️ " : "  "
                snippet += "\(prefix)\(String(format: "%3d", lineNum)) | \(lines[i])\n"
            }

            return snippet
        } catch {
            print("Error reading file for snippet: \(error)")
            return nil
        }
    }
}
