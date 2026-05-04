import SwiftUI
                                                                                                                                                                                                              
 struct ContentView: View {
     @StateObject private var vm = AppViewModel()
                                                                                                                                                                                                              
     var body: some View {
         VStack(spacing: 0) {
             // --- HEADER ---
             HStack {
                 Text("miniDebug")
                     .font(.system(size: 18, weight: .bold, design: .monospaced))
                 Button(action: { vm.selectProjectFolder() }) {
                           Label("Select Project", systemImage: "folder")
                               .font(.caption)
                       }
                       .buttonStyle(.bordered)
                       .padding(.leading, 10)        
                 Spacer()
                 Text("Ready")
                     .font(.caption)
                     .padding(.horizontal, 8)
                     .padding(.vertical, 2)
                     .background(Color.green.opacity(0.2))
                     .foregroundColor(.green)
                     .cornerRadius(4)
             }
             .padding()
             .background(Color(NSColor.windowBackgroundColor))
                                                                                                                                                                                                              
             Divider()
                                                                                                                                                                                                              
             // --- CONTROLS ---
             VStack(spacing: 12) {
                 // iOS Section
                 VStack(alignment: .leading, spacing: 8) {
                     Label("iOS Simulator", systemImage: "applelogo")
                         .font(.caption.bold())
                         .foregroundColor(.secondary)
                                                                                                                                                                                                              
                     HStack(spacing: 10) {
                         Button(action: { vm.triggerRunIOS() }) {
                             Label("Run", systemImage: "play.fill").frame(maxWidth: .infinity)
                         }.buttonStyle(.borderedProminent)
                                                                                                                                                                                                              
                         Button(action: { vm.triggerReload(platform: "ios") }) {
                             Label("Reload", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                         }.buttonStyle(.bordered)
                     }
                 }
                 .padding(.bottom, 8)
                                                                                                                                                                                                              
                 // Android Section
                 VStack(alignment: .leading, spacing: 8) {
                     Label("Android Emulator", systemImage: "android")
                         .font(.caption.bold())
                         .foregroundColor(.secondary)
                                                                                                                                                                                                              
                     HStack(spacing: 10) {
                         Button(action: { vm.triggerRunAndroid() }) {
                             Label("Run", systemImage: "play.fill").frame(maxWidth: .infinity)
                         }.buttonStyle(.borderedProminent)
                         Button(action: { vm.triggerReload(platform: "android") }) {
                             Label("Reload", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                         }.buttonStyle(.bordered)
                     }
                 }
                                                                                                                                                                                                              
                 Button(action: { vm.startLogStreaming() }) {
                     Label("Start Android Logs", systemImage: "list.bullet.rectangle.fill")
                         .frame(maxWidth: .infinity)
                 }.buttonStyle(.bordered).foregroundColor(.blue)
             }
             .padding()
             .background(Color(NSColor.controlBackgroundColor))
                                                                                                                                                                                                              
             // --- LOGS SECTION ---
             VStack(alignment: .trailing) {
                 HStack {
                     Text("CONSOLE OUTPUT")
                         .font(.system(size: 10, weight: .bold))
                         .foregroundColor(.gray)
                     Spacer()
                                                                                                                                                                                                              
                     HStack(spacing: 10) {
                         Button(action: { vm.clearLogs() }) {
                             Label("Clear", systemImage: "trash").font(.caption)
                         }.buttonStyle(.plain).foregroundColor(.gray)
                                                                                                                                                                                                              
                         Button(action: {
                             NSPasteboard.general.clearContents()
                             NSPasteboard.general.setString(vm.logs, forType: .string)
                         }) {
                             Label("Copy", systemImage: "doc.on.doc").font(.caption)
                         }.buttonStyle(.plain).foregroundColor(.gray)
                     }
                 }
                 .padding([.top, .horizontal], 8)
                 .padding(.bottom, 4)
                 .background(Color.black.opacity(0.9))
                                                                                                                                                                                                              
                 ScrollView {
                     Text(vm.logs)
                         .frame(maxWidth: .infinity, alignment: .leading)
                         .padding()
                         .font(.system(size: 12, design: .monospaced))
                 }
                 .frame(maxWidth: .infinity, maxHeight: .infinity)
                 .background(Color.black.opacity(0.9))
                 .foregroundColor(.green)
             }
         }
         .frame(width: 600, height: 500)
     }
 }         
