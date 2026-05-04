import Foundation
                                                                                                                                                                                                              
 enum ShellError: Error {
     case commandFailed(String)
 }
                                                                                                                                                                                                              
 class ShellService {
     static let shared = ShellService()
     private init() {}
                                                                                                                                                                                                              
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
         process.environment = ["PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"]
                                                                                                                                                                                                              
         try process.run()
         let data = pipe.fileHandleForReading.readDataToEndOfFile()
         process.waitUntilExit()
                                                                                                                                                                                                              
         let output = String(data: data, encoding: .utf8) ?? ""
         if process.terminationStatus != 0 {
             throw ShellError.commandFailed(output)
         }
         return output
     }
                                                                                                                                                                                                              
     // New: Detects the name of the currently booted simulator
          func getBootedSimulatorName() async -> String? {
              do {
                  // Correct command: list devices, then filter for booted and iPhones
                  let result = try await execute(command: "xcrun simctl list devices | grep '(Booted)' | grep 'iPhone' | sed 's/.*- //'")
                  let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
                  return trimmed.isEmpty ? nil : trimmed
              } catch {
                  return nil
              }
          }
                                                                                                                                                                                                              
     func stream(command: String, workingDirectory: String? = nil, onOutput: @escaping (String) -> Void) {
         let process = Process()
         let pipe = Pipe()
                                                                                                                                                                                                              
         process.executableURL = URL(fileURLWithPath: "/bin/zsh")
         process.arguments = ["-c", command]
                                                                                                                                                                                                              
         if let dir = workingDirectory {
             process.currentDirectoryURL = URL(fileURLWithPath: dir)
         }
                                                                                                                                                                                                              
         process.standardOutput = pipe
         process.standardError = pipe
         process.environment = ["PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/sbin"]
                                                                                                                                                                                                              
         pipe.fileHandleForReading.readabilityHandler = { handle in
             let data = handle.availableData
             if data.isEmpty { return }
             if let output = String(data: data, encoding: .utf8) {
                 DispatchQueue.main.async { onOutput(output) }
             }
         }
                                                                                                                                                                                                              
         do {
             try process.run()
         } catch {
             onOutput("❌ Failed to start stream: \(error)")
         }
     }
 } 
