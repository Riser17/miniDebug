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
     private var metroProcess: Process? = nil
                                                                                                                                                                                                                                                                              
     var filteredLogs: [LogEntry] {
         filterText.isEmpty ? allLogs : allLogs.filter { $0.text.localizedCaseInsensitiveContains(filterText) }
     }
                                                                                                                                                                                                                                                                              
     private var commands: RNCommands {
         RNCommands(projectPath: projectPath, adbPath: resolvedAdbPath)
     }
                                                                                                                                                                                                                                                                              
     init() {
         resolveAdbPath()
         updateAppName()
         fetchNodeVersion()
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
         }
     }
                                                                                                                                                                                                                                                                              
     func appendLog(_ text: String) {
         DispatchQueue.main.async {
             self.allLogs.append(LogEntry(text: text))
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
                 // Clear port 8081 first to avoid EADDRINUSE
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
             await MainActor.run { self.isRunningTask = true }
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
                   await MainActor.run { self.appendLog("✅ DevTools Opened: \(result)") }
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
                      // 1. Force kill port 8081 immediately
                      _ = try await ShellService.shared.execute(command: "lsof -ti:8081 | xargs kill -9 2>/dev/null")
                                                                                                                                                                                                                                                                                   
                      // 2. Start Metro with reset-cache as a STREAMING process (not execute)
                      // This prevents the UI from freezing
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
                                                                                                                                                                                                                                                                              
     func clearLogs() { allLogs = [] }
 }
