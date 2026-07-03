import SwiftUI

struct ErrorOverlayView: View {
    let error: ErrorDetail
    @ObservedObject var vm: AppViewModel

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.6)
                .edgesCancellable()
                .onTapGesture {
                    vm.clearActiveError()
                }

            VStack(spacing: 0) {
                // --- HEADER ---
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error.type.rawValue)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(error.message)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button(action: { vm.clearActiveError() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red)

                // --- CONTENT ---
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Code Preview
                        if let snippet = error.snippet {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Source Preview")
                                        .font(.caption.bold())
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Button(action: {
                                        if let frame = error.frames.first(where: { !$0.fileName.hasPrefix("http") }) {
                                            EditorManager.shared.openFile(at: frame.fileName, line: frame.line, column: frame.column)
                                        }
                                    }) {
                                        Label("Open in Editor", systemImage: "pencil.and.outline")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(.bottom, 8)

                                Text(snippet)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                    )
                            }
                        }

                        // Stack Trace
                        let openableFrames = error.frames.filter { !$0.fileName.hasPrefix("http") }
                        if !openableFrames.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Stack Trace")
                                    .font(.caption.bold())
                                    .foregroundColor(.gray)

                                VStack(spacing: 8) {
                                    ForEach(openableFrames) { frame in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(frame.fileName)
                                                    .font(.system(size: 12, design: .monospaced))
                                                    .foregroundColor(.blue)
                                                    .textSelection(.enabled)
                                                Text("Line \(frame.line), Col \(frame.column)")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Button(action: {
                                                EditorManager.shared.openFile(at: frame.fileName, line: frame.line, column: frame.column)
                                            }) {
                                                Image(systemName: "arrow.up.right.circle")
                                                    .foregroundColor(.gray)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(8)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(4)
                                    }
                                }
                            }
                        }

                        // AI Diagnosis
                        if let diagnosis = error.diagnosis {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.purple)
                                    Text("AI Diagnosis")
                                        .font(.caption.bold())
                                        .foregroundColor(.purple)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Root Cause:").font(.system(size: 12, weight: .bold))
                                    Text(diagnosis.rootCause).font(.system(size: 13)).foregroundColor(.secondary)

                                    Text("Suggested Fix:").font(.system(size: 12, weight: .bold))
                                    Text(diagnosis.suggestedFix).font(.system(size: 13)).foregroundColor(.secondary)

                                    HStack {
                                        Text("Confidence: \(diagnosis.confidence.rawValue)")
                                            .font(.system(size: 11))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.purple.opacity(0.2))
                                            .foregroundColor(.purple)
                                            .cornerRadius(4)
                                    }
                                }
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                            }
                        } else {
                            // AI Diagnosis Trigger
                            Button(action: { vm.fetchDiagnosis() }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Analyze with AI")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.purple)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: 600)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 20)
                .padding()
            }
        }
    }
}

extension View {
    func edgesCancellable() -> some View {
        self.edgesIgnoringSafeArea(.all)
    }
}
