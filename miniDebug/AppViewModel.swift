import Foundation
import Combine
import SwiftUI
import AppKit

enum LogLevel {
    case error, warn, info, debug
}

struct LogEntry: Identifiable {
    let id = UUID()
    let text: String
    let timestamp = Date()
    var isPinned: Bool = false

    var level: LogLevel {
        let upperText = text.uppercased()
        if upperText.contains("ERROR") || upperText.contains("FAILED") { return .error }
        if upperText.contains("WARN") { return .warn }
        if upperText.contains("INFO") { return .info }
        return .debug
    }
}

enum MaintenanceAction {
    case deepCleanIOS, deepCleanAndroid, podUpdate, metroReset
}

class AppViewModel: ObservableObject {
    @Published var allLogs: [LogEntry] = []
    @Published var filterText: String = ""
    @Published var projectPath: String = "/Users/harshvardhanrathore/dev/FocusBox"
    @Published var appName: String = "Unknown App"
    @Published var currentBranch: String = "No Branch"
    @Published var resolvedAdbPath: String = ""
    @Published var isRunningTask: Bool = false
    @Published var isMetroRunning: Bool = false
    @Published var nodeVersion: String = "Unknown"
    @Published var errorHistory: [ErrorDetail] = []
    @Published var activeError: ErrorDetail? = nil
    private var metroProcess: Process? = nil

    var filteredLogs: [LogEntry] {
        filterText.isEmpty ? allLogs : allLogs.filter { $0.text.localizedCaseInsensitiveContains(filterText) }
    }

    var pinnedLogs: [LogEntry] {
        allLogs.filter { $0.isPinned }
    }

    private var commands: RNCommands {
        RNCommands(projectPath: projectPath, adbPath: resolvedAdbPath)
    }

    init() {
        resolveAdbPath()
        updateAppName()
        fetchNodeVersion()

        // Automatically start streaming logs to detect errors in real-time
        startLogStreaming()
        startLogStreamingIOS()
    }

    func fetchNodeVersion() {
        Task {
            do {
                let version = try await ShellService.shared.execute(command: "node -v")
                await MainActor.run {
                    self.nodeVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch {
                await MainActor.run { self.nodeVersion = "Not Found" }
            }
        }
    }

    func resolveAdbPath() {
        Task {
            if let path = try? await ShellService.shared.execute(command: "which adb"), !path.isEmpty {
                await MainActor.run { self.resolvedAdbPath = path.trimmingCharacters(in: .whitespacesAndNewlines) }
                return
            }
            if let androidHome = ProcessInfo.processInfo.environment["ANDROID_HOME"] {
                await MainActor.run { self.resolvedAdbPath = "\(androidHome)/platform-tools/adb" }
                return
            }
            await MainActor.run { self.resolvedAdbPath = NSString(string: "~/Library/Android/sdk/platform-tools/adb").expandingTildeInPath }
        }
    }

    func updateAppName() {
        let packageJsonPath = "\(projectPath)/package.json"
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: packageJsonPath))
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let name = json["name"] as? String {
                self.appName = name
            } else {
                self.appName = (projectPath as NSString).lastPathComponent
            }
        } catch {
            self.appName = (projectPath as NSString).lastPathComponent
        }
        updateBranchName()
    }

    func updateBranchName() {
        Task {
            do {
                let branch = try await ShellService.shared.execute(command: "git rev-parse --abbrev-ref HEAD", workingDirectory: projectPath)
                await MainActor.run { self.currentBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines) }
            } catch {
                await MainActor.run { self.currentBranch = "No Branch" }
            }
        }
    }

    func selectProjectFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Select your React Native Project Folder"
        if panel.runModal() == .OK, let url = panel.url {
            self.projectPath = url.path
            self.appendLog("📂 Project folder changed to: \(url.path)")
            updateAppName()

            // Restart log streaming for the new project
            startLogStreaming()
            startLogStreamingIOS()
        }
    }

    func appendLog(_ text: String) {
        DispatchQueue.main.async {
            self.allLogs.append(LogEntry(text: text))
            self.processLog(text)
        }
    }

    private func processLog(_ text: String) {
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            if line.contains("FULL_STACK:") { continue } // supplementary data, not a new error

            if let (type, message) = ErrorDetector.shared.detect(text: line) {
                let stackContext = allLogs.suffix(50).map { $0.text }.joined(separator: "\n")

                var error = StackTraceParser.shared.parse(
                    message: message,
                    type: type,
                    rawStack: stackContext,
                    projectPath: projectPath
                )

                // A "usable" frame is a real file on disk. Bundle URLs
                // (http://localhost:8081/index.bundle?...) carry compiled
                // line numbers that don't map to source, so treat them as unusable.
                let usableFrame = error.frames.first(where: { !$0.fileName.hasPrefix("http") })

                if let firstFrame = usableFrame {
                    let fullPath = firstFrame.fileName.contains("/") ? firstFrame.fileName : "\(projectPath)/\(firstFrame.fileName)"
                    error.snippet = CodeSnippetService.shared.getSnippet(for: fullPath, line: firstFrame.line)
                } else {
                    // No usable local frame (either no frames, or only bundle-URL
                    // frames from a component stack). Try to symbolicate the
                    // compiled bundle location via Metro first — that gives an
                    // exact line/column instead of a heuristic guess.
                    let bundleFrame = error.frames.first(where: { $0.fileName.hasPrefix("http") })
                    self.appendLog("ℹ️ [source lookup] No local frame in stack — attempting symbolication")
                    Task {
                        var resolvedFrame: StackFrame? = nil

                        // Give a moment for a FULL_STACK: line (logged by the
                        // global error handler) to land, then re-read the
                        // freshest logs — it's the real throw-site stack,
                        // more precise than the component stack we started with.
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        let freshContext = await MainActor.run { self.allLogs.suffix(50).map { $0.text }.joined(separator: "\n") }

                        if let throwSiteFrame = self.firstFrameFromFullStack(in: freshContext) {
                            self.appendLog("🎯 [source lookup] Using real throw-site frame from FULL_STACK")
                            resolvedFrame = await self.symbolicateFrame(fileURL: throwSiteFrame.fileName, line: throwSiteFrame.line, column: throwSiteFrame.column)
                        }

                        if resolvedFrame == nil, let bf = bundleFrame {
                            resolvedFrame = await self.symbolicateFrame(fileURL: bf.fileName, line: bf.line, column: bf.column)
                        }

                        if resolvedFrame == nil {
                            self.appendLog("ℹ️ [source lookup] Symbolication unavailable — falling back to symbol search")
                            resolvedFrame = await self.resolveFrameBySymbolGrep(message: message, stackContext: stackContext)
                        }

                        if let frame = resolvedFrame {
                            let fullPath = frame.fileName.contains("/") ? frame.fileName : "\(projectPath)/\(frame.fileName)"
                            let snippet = CodeSnippetService.shared.getSnippet(for: fullPath, line: frame.line)

                            await MainActor.run {
                                if let index = self.errorHistory.firstIndex(where: { $0.id == error.id }) {
                                    self.errorHistory[index].frames = [frame] + self.errorHistory[index].frames
                                    self.errorHistory[index].snippet = snippet
                                    self.activeError = self.errorHistory[index]
                                }
                            }
                        }
                    }
                }

                DispatchQueue.main.async {
                    self.errorHistory.insert(error, at: 0)
                    self.activeError = error
                }
            }
        }
    }

    private func firstFrameFromFullStack(in logText: String) -> StackFrame? {
        guard let markerRange = logText.range(of: "FULL_STACK:") else { return nil }
        let stackText = String(logText[markerRange.upperBound...])
        let frames = StackTraceParser.shared.extractFrames(from: stackText)
        // First frame in a JS stack trace is the innermost call — the
        // actual throw site — not an outer caller.
        return frames.first
    }

    private func symbolicateFrame(fileURL: String, line: Int, column: Int) async -> StackFrame? {
        // Metro's dev server can map a compiled bundle location back to the
        // original source file/line — the same mechanism LogBox itself uses
        // to show e.g. "TimerScreen.tsx (32:17)" in the simulator.
        guard let url = URL(string: "http://localhost:8081/symbolicate") else { return nil }

        let payload: [String: Any] = [
            "stack": [[
                "file": fileURL,
                "methodName": "unknown",
                "lineNumber": line,
                "column": column
            ]]
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        self.appendLog("🔍 [symbolicate] Requesting Metro to resolve \(fileURL) @ \(line):\(column)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                self.appendLog("⚠️ [symbolicate] Metro returned a non-200 response")
                return nil
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stack = json["stack"] as? [[String: Any]],
                  let frame = stack.first,
                  let file = frame["file"] as? String,
                  let symLine = frame["lineNumber"] as? Int,
                  !file.hasPrefix("http") else {
                let raw = String(data: data, encoding: .utf8) ?? "<unreadable>"
                self.appendLog("⚠️ [symbolicate] Couldn't parse a local source location. Raw response: \(raw.prefix(300))")
                return nil
            }
            let symColumn = frame["column"] as? Int ?? 0
            self.appendLog("✅ [symbolicate] Resolved to \(file):\(symLine)")
            return StackFrame(fileName: file, line: symLine, column: symColumn, functionName: frame["methodName"] as? String, isExternal: file.contains("node_modules"))
        } catch {
            self.appendLog("⚠️ [symbolicate] Request failed (is Metro running on :8081?): \(error)")
            return nil
        }
    }

    private func resolveFrameBySymbolGrep(message: String, stackContext: String) async -> StackFrame? {
        // Extract the first quoted identifier from the message, e.g.
        // "Unable to resolve module 'XYZ'" -> "XYZ"
        // "Property 'StatusBar' doesn't exist" -> "StatusBar"
        let quotedPattern = "['\"]([^'\"]+)['\"]"
        var symbol: String? = nil

        if let regex = try? NSRegularExpression(pattern: quotedPattern),
           let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
           let range = Range(match.range(at: 1), in: message) {
            symbol = String(message[range])
        }

        // Fallback 1: React warnings often say "Check the render method of
        // `ComponentName`." on a line separate from the main message, so
        // it wouldn't be in `message` but will be in the recent log context.
        if symbol == nil {
            let backtickPattern = "`([A-Za-z_][A-Za-z0-9_]*)`"
            if let regex = try? NSRegularExpression(pattern: backtickPattern),
               let match = regex.firstMatch(in: stackContext, range: NSRange(stackContext.startIndex..., in: stackContext)),
               let range = Range(match.range(at: 1), in: stackContext) {
                symbol = String(stackContext[range])
                if let s = symbol {
                    self.appendLog("ℹ️ [source lookup] No symbol in message — using backtick-quoted name from logs: '\(s)'")
                }
            }
        }

        // Fallback 2: first non-generic component name from "at X (...)" in
        // the component stack.
        if symbol == nil {
            symbol = firstMeaningfulComponentName(in: stackContext)
            if let s = symbol {
                self.appendLog("ℹ️ [source lookup] No symbol in message or logs — using component stack instead: '\(s)'")
            }
        }

        guard let moduleName = symbol else {
            self.appendLog("⚠️ [source lookup] Couldn't extract a symbol name from message or stack")
            return nil
        }

        // Prefer the file that actually IS the component (e.g. TimerScreen.tsx)
        // over any file that merely references it (e.g. an import line in
        // AppNavigator.tsx) — otherwise we send people to the wrong place.
        if let definitionFrame = await findDefinitionFile(named: moduleName) {
            return definitionFrame
        }

        self.appendLog("🔍 [source lookup] Searching \(projectPath) for '\(moduleName)'...")
        let grepCommand = "grep -rn --include=\"*.js\" --include=\"*.ts\" --include=\"*.tsx\" --include=\"*.jsx\" --exclude-dir=node_modules \"\(moduleName)\" \"\(projectPath)\" | head -n 1"

        do {
            let result = try await ShellService.shared.execute(command: grepCommand)
            let lines = result.components(separatedBy: .newlines)
            if let firstLine = lines.first, !firstLine.isEmpty {
                // grep -rn output: file:line:content
                let parts = firstLine.components(separatedBy: ":")
                if parts.count >= 2 {
                    let fileName = parts[0]
                    let line = Int(parts[1]) ?? 0
                    self.appendLog("✅ [source lookup] Found '\(moduleName)' at \(fileName):\(line)")
                    return StackFrame(fileName: fileName, line: line, column: 0, functionName: nil, isExternal: false)
                }
            }
            self.appendLog("⚠️ [source lookup] No match for '\(moduleName)' under \(projectPath). Is projectPath set to your RN project root?")
        } catch {
            self.appendLog("⚠️ [source lookup] grep failed: \(error)")
        }
        return nil
    }

    private func findDefinitionFile(named moduleName: String) async -> StackFrame? {
        let findCommand = "find \"\(projectPath)\" -type f \\( -iname \"\(moduleName).tsx\" -o -iname \"\(moduleName).ts\" -o -iname \"\(moduleName).jsx\" -o -iname \"\(moduleName).js\" \\) -not -path \"*/node_modules/*\" | head -n 1"

        guard let findResult = try? await ShellService.shared.execute(command: findCommand) else { return nil }
        let filePath = findResult.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filePath.isEmpty else { return nil }

        self.appendLog("✅ [source lookup] '\(moduleName)' is defined in \(filePath)")

        // Land somewhere more useful than line 1 when possible. We don't know
        // the exact crash line (that requires symbolication, which needs
        // coordinates the OS log may have truncated away), so use the best
        // available anchor as an approximation, in priority order.
        let anchors = [
            ("last useEffect", "grep -n \"useEffect(\" \"\(filePath)\" | tail -n 1"),
            ("last export", "grep -n \"export\" \"\(filePath)\" | tail -n 1")
        ]

        for (label, command) in anchors {
            if let result = try? await ShellService.shared.execute(command: command) {
                let firstLine = result.components(separatedBy: .newlines).first ?? ""
                let parts = firstLine.components(separatedBy: ":")
                if parts.count >= 2, let line = Int(parts[1]) {
                    self.appendLog("ℹ️ [source lookup] Exact crash line unavailable (log truncated) — approximating via \(label) at line \(line)")
                    return StackFrame(fileName: filePath, line: line, column: 0, functionName: nil, isExternal: false)
                }
            }
        }

        self.appendLog("ℹ️ [source lookup] No anchor found — opening \(filePath) at top of file")
        return StackFrame(fileName: filePath, line: 1, column: 0, functionName: nil, isExternal: false)
    }

    // Blocklist of generic React Native internal wrapper names that show up
    // constantly in component stacks and are never the file you actually want.
    private static let genericComponentNames: Set<String> = [
        "View_withRef", "RCTView", "AppContainer", "Fragment", "ForwardRef",
        "Anonymous", "View", "Text", "ScrollView", "SafeAreaProvider"
    ]

    private func firstMeaningfulComponentName(in stackContext: String) -> String? {
        let pattern = "at ([A-Z][A-Za-z0-9_]*)\\s*\\("
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(stackContext.startIndex..., in: stackContext)
        let matches = regex.matches(in: stackContext, range: nsRange)

        for match in matches {
            guard let range = Range(match.range(at: 1), in: stackContext) else { continue }
            let name = String(stackContext[range])
            if !Self.genericComponentNames.contains(name) {
                return name
            }
        }
        return nil
    }

    func clearErrorHistory() {
        errorHistory = []
        activeError = nil
    }

    func clearActiveError() {
        activeError = nil
    }

    func fetchDiagnosis() {
        guard let error = activeError else { return }
        Task {
            if let diagnosis = await AIDiagnosisService.shared.diagnose(error: error) {
                await MainActor.run {
                    self.activeError?.diagnosis = diagnosis
                }
            }
        }
    }

    func togglePin(for entry: LogEntry) {
        if let index = allLogs.firstIndex(where: { $0.id == entry.id }) {
            allLogs[index].isPinned.toggle()
        }
    }

    // --- METRO TERMINAL CONTROL ---
    func startMetroServer() {
        Task {
            await MainActor.run {
                if isMetroRunning {
                    self.appendLog("⚠️  Metro is already running. Kill it first!")
                    return
                }
                self.isRunningTask = true
            }
            do {
                _ = try await ShellService.shared.execute(command: "lsof -ti:8081 | xargs kill -9 2>/dev/null")

                let process = try ShellService.shared.startStreamingProcess(
                    command: commands.startMetro,
                    workingDirectory: projectPath
                ) { newLog in
                    self.appendLog(newLog)
                }

                self.metroProcess = process
                await MainActor.run {
                    self.isMetroRunning = true
                    self.isRunningTask = false
                    self.appendLog("🚀 Metro Server Started!")
                }
            } catch {
                await MainActor.run {
                    self.appendLog("❌ Failed to start Metro: \(error)")
                    self.isRunningTask = false
                }
            }
        }
    }

    func killMetroServer() {
        if let process = metroProcess {
            process.terminate()
            metroProcess = nil
            appendLog("🛑 Metro Server killed.")
            isMetroRunning = false
        } else {
            appendLog("⚠️  No running server to kill.")
        }
    }

    // --- EXISTING TRIGGER METHODS ---
    func triggerRunIOS() {
        Task {
            await MainActor.run {
                self.isRunningTask = true
                self.clearErrorHistory()
            }
            do {
                let simulatorName = await ShellService.shared.getBootedSimulatorName()
                var finalCommand = commands.runIOS
                if let name = simulatorName {
                    finalCommand = "npx react-native run-ios --simulator \"\(name)\" --no-packager"
                    await MainActor.run { self.appendLog("🎯 Targeting Booted Simulator: \(name)") }
                }
                let result = try await ShellService.shared.execute(command: finalCommand, workingDirectory: projectPath)
                await MainActor.run { self.appendLog("✅ Run iOS Success:\n\(result)") }
            } catch {
                await MainActor.run { self.appendLog("❌ Run iOS Failed: \(error)") }
            }
            await MainActor.run { self.isRunningTask = false }
        }
    }

    func triggerRunAndroid() {
        Task {
            await MainActor.run { self.isRunningTask = true }
            do {
                let result = try await ShellService.shared.execute(command: commands.runAndroid, workingDirectory: projectPath)
                await MainActor.run { self.appendLog("✅ Run Android Success:\n\(result)") }
            } catch {
                await MainActor.run { self.appendLog("❌ Run Android Failed: \(error)") }
            }
            await MainActor.run { self.isRunningTask = false }
        }
    }

    func triggerReload(platform: String) {
        Task {
            await MainActor.run { self.clearErrorHistory() }
            do {
                let command = platform == "ios" ? commands.reloadIOS : commands.reloadAndroid
                let result = try await ShellService.shared.execute(command: command)
                await MainActor.run { self.appendLog("✅ Reloaded \(platform): \(result)") }
            } catch {
                await MainActor.run { self.appendLog("❌ Reload Failed: \(error)") }
            }
        }
    }

    func triggerInspect(platform: String) {
        Task {
            do {
                let command = platform == "ios" ? commands.inspectIOS : commands.inspectAndroid
                let result = try await ShellService.shared.execute(command: command)
                await MainActor.run { self.appendLog("✅ Inspect \(platform): \(result)") }
            } catch {
                await MainActor.run { self.appendLog("❌ Inspect Failed: \(error)") }
            }
        }
    }
    func triggerDevTools() {
          Task {
              do {
                  let result = try await ShellService.shared.execute(command: commands.devtools)
                  await MainActor.run { self.appendLog("✅ Debugging Suite Opened in Chrome.") }
              } catch {
                  await MainActor.run { self.appendLog("❌ Failed to open DevTools: \(error)") }
              }
          }
      }
    func triggerDeepClean(platform: String) {
        Task {
            await MainActor.run { self.isRunningTask = true }
            do {
                let command = platform == "ios" ? commands.deepCleanIOS : commands.deepCleanAndroid
                let result = try await ShellService.shared.execute(command: command, workingDirectory: projectPath)
                await MainActor.run { self.appendLog("✅ Deep Clean Success:\n\(result)") }
            } catch {
                await MainActor.run { self.appendLog("❌ Deep Clean Failed: \(error)") }
            }
            await MainActor.run { self.isRunningTask = false }
        }
    }

    func triggerPodUpdate() {
        Task {
            await MainActor.run { self.isRunningTask = true }
            do {
                let result = try await ShellService.shared.execute(command: commands.podUpdate, workingDirectory: projectPath)
                await MainActor.run { self.appendLog("✅ Pod Update Success:\n\(result)") }
            } catch {
                await MainActor.run { self.appendLog("❌ Pod Update Failed: \(error)") }
            }
            await MainActor.run { self.isRunningTask = false }
        }
    }

    func triggerMetroReset() {
            Task {
                await MainActor.run { self.isRunningTask = true }
                do {
                    _ = try await ShellService.shared.execute(command: "lsof -ti:8081 | xargs kill -9 2>/dev/null")
                    let process = try ShellService.shared.startStreamingProcess(
                        command: commands.metroReset,
                        workingDirectory: projectPath
                    ) { newLog in
                        self.appendLog(newLog)
                    }
                    self.metroProcess = process
                    await MainActor.run {
                        self.isMetroRunning = true
                        self.isRunningTask = false
                        self.appendLog("🔄 Metro Reset: Server restarting with cleared cache...")
                    }
                } catch {
                    await MainActor.run {
                        self.appendLog("❌ Metro Reset Failed: \(error)")
                        self.isRunningTask = false
                    }
                }
            }
        }

    func getCommand(for action: MaintenanceAction) -> String {
        switch action {
        case .deepCleanIOS: return commands.deepCleanIOS
        case .deepCleanAndroid: return commands.deepCleanAndroid
        case .podUpdate: return commands.podUpdate
        case .metroReset: return commands.metroReset
        }
    }

    func startLogStreaming() {
        ShellService.shared.stream(command: commands.logAndroid, workingDirectory: projectPath) { newLog in
            self.appendLog(newLog)
        }
    }

    func startLogStreamingIOS() {
        ShellService.shared.stream(command: commands.logIOS, workingDirectory: projectPath) { newLog in
            self.appendLog(newLog)
        }
    }

    func clearLogs() { allLogs = [] }

    // --- NEW: Selective Package Update ---
    func triggerUpdatePackage(name: String, version: String?) {
        Task {
            await MainActor.run { self.isRunningTask = true }
            do {
                let packageSpec = version != nil && !version!.isEmpty ? "\(name)@\(version!)" : name
                appendLog("📦 Updating package \(packageSpec)...")

                let installCommand = "npm install \(packageSpec)"
                let podCommand = "cd ios && pod install"

                let result = try await ShellService.shared.execute(command: "\(installCommand) && \(podCommand)", workingDirectory: projectPath)
                await MainActor.run { self.appendLog("✅ Package Updated Successfully:\n\(result)") }
            } catch {
                await MainActor.run { self.appendLog("❌ Package Update Failed: \(error)") }
            }
            await MainActor.run { self.isRunningTask = false }
        }
    }
}
