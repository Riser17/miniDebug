import Foundation

class EditorManager {
    static let shared = EditorManager()
    private init() {}

    func openFile(at path: String, line: Int, column: Int) {
        guard !path.hasPrefix("http://") && !path.hasPrefix("https://") else {
            print("Skipped opening editor: not a local file path (\(path))")
            return
        }
        let editor = detectEditor()
        let fullPath = path
        let lineCol = "\(line):\(column)"

        // Most modern editors use the --goto or -g flag for line/col
        let command = "\(editor) --goto \(fullPath):\(lineCol)"

        Task {
            do {
                _ = try await ShellService.shared.execute(command: command)
            } catch {
                print("Failed to open editor: \(error)")
                // Fallback to standard 'open' if CLI tool fails
                let fallback = "open -a \"Visual Studio Code\" \(fullPath)"
                _ = try? await ShellService.shared.execute(command: fallback)
            }
        }
    }

    private func detectEditor() -> String {
        // Check for Cursor first, then VS Code
        if isCommandAvailable("cursor") {
            return "cursor"
        } else if isCommandAvailable("code") {
            return "code"
        }
        return "code" // Default to code
    }

    private func isCommandAvailable(_ command: String) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var available = false

        Task {
            do {
                let result = try await ShellService.shared.execute(command: "which \(command)")
                available = !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } catch {
                available = false
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 1.0)
        return available
    }
}
