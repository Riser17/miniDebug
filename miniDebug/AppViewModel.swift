import Foundation
import Combine
import SwiftUI
import AppKit
                                                                                                                                                                                                               
  class AppViewModel: ObservableObject {
      @Published var logs: String = ""
      @Published var projectPath: String = "/Users/harshvardhanrathore/dev/FocusBox" // Default
      
      // Changed to a computed property so it always uses the current projectPath
           private var commands: RNCommands {
               RNCommands(projectPath: projectPath)
           }
      
      func selectProjectFolder() {
          let panel = NSOpenPanel()
               panel.allowsMultipleSelection = false
               panel.canChooseDirectories = true
               panel.canChooseFiles = false
               // panel.canChooseAccessories = false // ❌ REMOVE THIS LINE
               panel.prompt = "Select your React Native Project Folder"
                                                                                                                                                                                                                        
               if panel.runModal() == .OK {
                   if let url = panel.url {
                       self.projectPath = url.path
                       self.logs += "\n📂 Project folder changed to: \(url.path)"
                   }
               }
               
            }
      
      func triggerRunIOS() {
                Task {
                    do {
                        let simulatorName = await ShellService.shared.getBootedSimulatorName()
                        var finalCommand = commands.runIOS
                                                                                                                                                                                                                     
                        if let name = simulatorName {
                            // Use double quotes for the simulator name to handle spaces safely
                            finalCommand = "npx react-native run-ios --simulator \"\(name)\" --no-packager"
                            await MainActor.run { self.logs += "\n🎯 Targeting Booted Simulator: \(name)" }
                        }
                                                                                                                                                                                                                     
                        let result = try await ShellService.shared.execute(command: finalCommand, workingDirectory: projectPath)
                        await MainActor.run { self.logs += "\n✅ Run iOS Success:\n\(result)" }
                    } catch {
                        await MainActor.run { self.logs += "\n❌ Run iOS Failed: \(error)" }
                    }
                }
            }
                                                                                                                                                                                                               
      func triggerRunAndroid() {
          Task {
              do {
                  let result = try await ShellService.shared.execute(command: commands.runAndroid, workingDirectory: projectPath)
                  await MainActor.run { self.logs += "\n✅ Run Android Success:\n\(result)" }
              } catch {
                  await MainActor.run { self.logs += "\n❌ Run Android Failed: \(error)" }
              }
          }
      }
                                                                                                                                                                                                               
      func triggerReload(platform: String) {
          Task {
              do {
                  let command = platform == "ios" ? commands.reloadIOS : commands.reloadAndroid
                  let result = try await ShellService.shared.execute(command: command)
                  await MainActor.run { self.logs += "\n✅ Reloaded \(platform): \(result)" }
              } catch {
                  await MainActor.run { self.logs += "\n❌ Reload Failed: \(error)" }
              }
          }
      }
                                                                                                                                                                                                               
      func startLogStreaming() {
          ShellService.shared.stream(command: commands.logAndroid, workingDirectory: projectPath) { newLog in
              self.logs += newLog
          }
      }
                                                                                                                                                                                                               
      func clearLogs() {
          logs = ""
      }
  }   
