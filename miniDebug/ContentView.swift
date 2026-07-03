import SwiftUI

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @State private var activeInfoCommand: String? = nil
    @State private var pkgName: String = ""
    @State private var pkgVersion: String = ""

    var body: some View {
        HStack(spacing: 0) {
            // --- LEFT SIDEBAR: ERROR HISTORY ---
            VStack(spacing: 0) {
                HStack {
                    Text("ERRORS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                    Button(action: { vm.clearErrorHistory() }) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.black.opacity(0.2))

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if vm.errorHistory.isEmpty {
                            Text("No errors detected")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(vm.errorHistory) { error in
                                Button(action: { vm.activeError = error }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(error.type.rawValue)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(errorTypeColor(error.type))
                                            Spacer()
                                            Text(error.timestamp, style: .time)
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                        }
                                        Text(error.message)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.9))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(vm.activeError?.id == error.id ? Color.blue.opacity(0.2) : Color.clear)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider().background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            }
            .frame(width: 300)
            .border(Color.gray.opacity(0.2), width: 1)

            // --- MAIN CONTENT AREA ---
            ZStack {
                VStack(spacing: 0) {
                    // --- HEADER ---
                    HStack {
                        VStack(alignment: .leading) {
                            Text("miniDebug")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                            HStack {
                                Text(vm.appName)
                                Text("•")
                                Text(vm.currentBranch)
                                    .italic()
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        }

                        Button(action: { vm.selectProjectFolder() }) {
                            Label("Select Project", systemImage: "folder")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .padding(.leading, 10)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "node.symbol")
                                Text("Node: \(vm.nodeVersion)")
                            }
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)

                            if vm.isRunningTask {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Ready")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))

                    Divider()

                    // --- CONTROLS ---
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("iOS Simulator", systemImage: "applelogo")
                                    .font(.caption.bold()).foregroundColor(.secondary)
                                HStack(spacing: 10) {
                                    VStack {
                                        Button(action: { vm.triggerRunIOS() }) {
                                            Label("Run", systemImage: "play.fill").frame(maxWidth: .infinity)
                                        }.buttonStyle(.borderedProminent)
                                        Text("").font(.system(size: 9))
                                    }

                                    VStack {
                                        Button(action: { vm.triggerReload(platform: "ios") }) {
                                            Label("Reload", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                                        }.buttonStyle(.bordered)
                                        .keyboardShortcut("r", modifiers: [.command])
                                        Text("[⌘R]").font(.system(size: 9)).foregroundColor(.gray)
                                    }

                                    VStack {
                                        Button(action: { vm.triggerInspect(platform: "ios") }) {
                                            Label("Inspect", systemImage: "eye").frame(maxWidth: .infinity)
                                        }.buttonStyle(.bordered)
                                        .keyboardShortcut("d", modifiers: [.command])
                                        Text("[⌘D]").font(.system(size: 9)).foregroundColor(.gray)
                                    }

                                    VStack {
                                        Button(action: { vm.triggerDevTools() }) {
                                            Label("DevTools", systemImage: "cpu").frame(maxWidth: .infinity)
                                        }.buttonStyle(.bordered)
                                        .keyboardShortcut("j", modifiers: [.command])
                                        Text("[⌘J]").font(.system(size: 9)).foregroundColor(.gray)
                                    }
                                }
                            }
                            Divider().frame(height: 100).padding(.horizontal)
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Android Emulator", systemImage: "android")
                                    .font(.caption.bold()).foregroundColor(.secondary)
                                HStack(spacing: 10) {
                                    VStack {
                                        Button(action: { vm.triggerRunAndroid() }) {
                                            Label("Run", systemImage: "play.fill").frame(maxWidth: .infinity)
                                        }.buttonStyle(.borderedProminent)
                                        Text("").font(.system(size: 9))
                                    }
                                    VStack {
                                        Button(action: { vm.triggerReload(platform: "android") }) {
                                            Label("Reload", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                                        }.buttonStyle(.bordered)
                                        .keyboardShortcut("r", modifiers: [.command, .shift])
                                        Text("[⌘⇧R]").font(.system(size: 9)).foregroundColor(.gray)
                                    }
                                    VStack {
                                        Button(action: { vm.triggerInspect(platform: "android") }) {
                                            Label("Inspect", systemImage: "eye").frame(maxWidth: .infinity)
                                        }.buttonStyle(.bordered)
                                        .keyboardShortcut("d", modifiers: [.command, .shift])
                                        Text("[⌘⇧D]").font(.system(size: 9)).foregroundColor(.gray)
                                    }
                                    VStack {
                                        Button(action: { vm.triggerDevTools() }) {
                                            Label("DevTools", systemImage: "cpu").frame(maxWidth: .infinity)
                                        }.buttonStyle(.bordered)
                                        .keyboardShortcut("j", modifiers: [.command, .shift])
                                        Text("[⌘⇧J]").font(.system(size: 9)).foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 8)

                        // Maintenance Section
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Maintenance", systemImage: "wrench.adjustable")
                                .font(.caption.bold()).foregroundColor(.secondary)

                            HStack(spacing: 10) {
                                Button(action: { vm.startMetroServer() }) {
                                    Label("Start Metro", systemImage: "play.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(vm.isMetroRunning)
                                .foregroundColor(.green)

                                Button(action: { vm.killMetroServer() }) {
                                    Label("Kill Metro", systemImage: "stop.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!vm.isMetroRunning)
                                .foregroundColor(.red)
                            }
                            .padding(.bottom, 4)

                            HStack(spacing: 10) {
                                HStack(spacing: 4) {
                                    Button(action: { activeInfoCommand = vm.getCommand(for: .deepCleanIOS) }) {
                                        Image(systemName: "info.circle").font(.caption)
                                    }
                                    .buttonStyle(.plain).foregroundColor(.secondary)
                                    .popover(isPresented: Binding(
                                        get: { activeInfoCommand == vm.getCommand(for: .deepCleanIOS) },
                                        set: { if !$0 { activeInfoCommand = nil } }
                                    )) { infoPopoverView }

                                    Button(action: { vm.triggerDeepClean(platform: "ios") }) {
                                        Label("Deep Clean", systemImage: "trash.fill").frame(maxWidth: .infinity)
                                    }.buttonStyle(.bordered)
                                }

                                HStack(spacing: 4) {
                                    Button(action: { activeInfoCommand = vm.getCommand(for: .podUpdate) }) {
                                        Image(systemName: "info.circle").font(.caption)
                                    }
                                    .buttonStyle(.plain).foregroundColor(.secondary)
                                    .popover(isPresented: Binding(
                                        get: { activeInfoCommand == vm.getCommand(for: .podUpdate) },
                                        set: { if !$0 { activeInfoCommand = nil } }
                                    )) { infoPopoverView }

                                    Button(action: { vm.triggerPodUpdate() }) {
                                        Label("Pod Update", systemImage: "arrow.clockwise.circle.fill").frame(maxWidth: .infinity)
                                    }.buttonStyle(.bordered)
                                }

                                HStack(spacing: 4) {
                                    Button(action: { activeInfoCommand = vm.getCommand(for: .metroReset) }) {
                                        Image(systemName: "info.circle").font(.caption)
                                    }
                                    .buttonStyle(.plain).foregroundColor(.secondary)
                                    .popover(isPresented: Binding(
                                        get: { activeInfoCommand == vm.getCommand(for: .metroReset) },
                                        set: { if !$0 { activeInfoCommand = nil } }
                                    )) { infoPopoverView }

                                    Button(action: { vm.triggerMetroReset() }) {
                                        Label("Metro Reset", systemImage: "cpu").frame(maxWidth: .infinity)
                                    }.buttonStyle(.bordered)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Selective Package Update")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.gray)
                                HStack {
                                    TextField("Package Name", text: $pkgName)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 150)
                                    TextField("Version (optional)", text: $pkgVersion)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 120)
                                    Button(action: {
                                        vm.triggerUpdatePackage(name: pkgName, version: pkgVersion.isEmpty ? nil : pkgVersion)
                                        pkgName = ""
                                        pkgVersion = ""
                                    }) {
                                        Label("Update", systemImage: "arrow.up.circle.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(pkgName.isEmpty || vm.isRunningTask)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 8)
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
                            TextField("Filter logs...", text: $vm.filterText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                                .font(.system(size: 11))
                                .padding(.trailing, 8)
                            HStack(spacing: 10) {
                                Button(action: { vm.clearLogs() }) {
                                    Label("Clear", systemImage: "trash").font(.caption)
                                }.buttonStyle(.plain).foregroundColor(.gray)
                                Button(action: {
                                    let allText = vm.allLogs.map { $0.text }.joined(separator: "\n")
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(allText, forType: .string)
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc").font(.caption)
                                }.buttonStyle(.plain).foregroundColor(.gray)
                            }
                        }
                        .padding([.top, .horizontal], 8)
                        .padding(.bottom, 4)
                        .background(Color.black.opacity(0.9))

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(vm.filteredLogs) { entry in
                                    HStack {
                                        Text(entry.text)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(
                                                entry.level == .error ? .red :
                                                entry.level == .warn ? .yellow :
                                                entry.level == .info ? .blue : .green
                                            )
                                            .padding(.horizontal)
                                            .padding(.vertical, 2)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Button(action: { vm.togglePin(for: entry) }) {
                                            Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                                                .font(.system(size: 10))
                                                .foregroundColor(entry.isPinned ? .yellow : .gray)
                                                .padding(.trailing, 8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.9))
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.9))
                        }
                    }
                }
                .frame(width: 900, height: 600)
            }

            if let error = vm.activeError {
                ErrorOverlayView(error: error, vm: vm)
            }
        }
    }

    private func errorTypeColor(_ type: ErrorType) -> Color {
        switch type {
        case .importError: return .orange
        case .runtimeError: return .red
        case .syntaxError: return .yellow
        case .nativeError: return .purple
        case .hookError: return .blue
        case .navError: return .green
        case .unknown: return .gray
        }
    }

    @ViewBuilder
    var infoPopoverView: some View {
        if let command = activeInfoCommand {
            Text(command)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .frame(minWidth: 300, alignment: .leading)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(8)
        } else {
            Text("No command available").padding()
        }
    }
}
