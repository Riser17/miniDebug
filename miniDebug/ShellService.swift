import Foundation
                                                                                                                                                                                                                                                                               
  enum ShellError: Error {
      case commandFailed(String)
  }
                                                                                                                                                                                                                                                                               
  class ShellService {
      static let shared = ShellService()
      private init() {}
                                                                                                                                                                                                                                                                               
      // This expanded PATH ensures that 'sh', 'npm', 'node', and 'git' are all found.
      private var expandedPath: String {
          let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
          let standardPaths = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
          return "\(standardPaths):\(currentPath)"
      }
                                                                                                                                                                                                                                                                               
      func execute(command: String, workingDirectory: String? = nil) async throws -> String {
          let process = Process()
          let pipe = Pipe()
                                                                                                                                                                                                                                                                               
          process.executableURL = URL(fileURLWithPath: "/bin/zsh")
          process.arguments = ["-c", command]
                                                                                                                                                                                                                                                                               
          if let dir = workingDirectory {
              process.currentDirectoryURL = URL(fileURLWithPath: dir)
          }
          process.standardOutput = pipe
          process.standardError = pipe
                                                                                                                                                                                                                                                                               
          process.environment = ["PATH": expandedPath]
                                                                                                                                                                                                                                                                               
          try process.run()
          let data = pipe.fileHandleForReading.readDataToEndOfFile()
          process.waitUntilExit()
                                                                                                                                                                                                                                                                               
          let output = String(data: data, encoding: .utf8) ?? ""
          if process.terminationStatus != 0 {
              throw ShellError.commandFailed(output)
          }
          return output
      }
                                                                                                                                                                                                                                                                               
      func getBootedSimulatorName() async -> String? {
          do {
              let result = try await execute(command: "xcrun simctl list devices | grep '(Booted)' | grep 'iPhone' | sed 's/.*- //'")
              let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
              return trimmed.isEmpty ? nil : trimmed
          } catch {
              return nil
          }
      }
                                                                                                                                                                                                                                                                               
      // Original stream method (for logs)
      func stream(command: String, workingDirectory: String? = nil, onOutput: @escaping (String) -> Void) {
          _ = try? startStreamingProcess(command: command, workingDirectory: workingDirectory, onOutput: onOutput)
      }
                                                                                                                                                                                                                                                                               
      // NEW: This version returns the Process object so the ViewModel can kill it later
      func startStreamingProcess(command: String, workingDirectory: String? = nil, onOutput: @escaping (String) -> Void) throws -> Process {
          let process = Process()
          let pipe = Pipe()
                                                                                                                                                                                                                                                                               
          process.executableURL = URL(fileURLWithPath: "/bin/zsh")
          process.arguments = ["-c", command]
                                                                                                                                                                                                                                                                               
          if let dir = workingDirectory {
              process.currentDirectoryURL = URL(fileURLWithPath: dir)
          }
          process.standardOutput = pipe
          process.standardError = pipe
                                                                                                                                                                                                                                                                               
          process.environment = ["PATH": expandedPath]
                                                                                                                                                                                                                                                                               
          pipe.fileHandleForReading.readabilityHandler = { handle in
              let data = handle.availableData
              if data.isEmpty { return }
              if let output = String(data: data, encoding: .utf8) {
                  DispatchQueue.main.async { onOutput(output) }
              }
          }
                                                                                                                                                                                                                                                                               
          try process.run()
          return process
      }
  }             
