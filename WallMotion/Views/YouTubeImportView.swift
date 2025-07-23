//
//  YouTubeImportView.swift
//  WallMotion
//
//  Main YouTube Import View - Final version with complete loading states
//

import SwiftUI
import AVKit

struct YouTubeImportView: View {
    @StateObject private var importManager = YouTubeImportManager()
    @State private var youtubeURL = ""
    @State private var showingVideoInfo = false
    @State private var showingTimeSelector = false
    @State private var showingDependencyAlert = false
    @State private var dependencyMessage = ""
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0.0
    @State private var processingMessage = ""
    @State private var isFetchingVideoInfo = false
    @State private var showingDiagnostics = false
    @State private var diagnosticsReport = ""
    
    let onVideoReady: (URL) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                YouTubeImportHeader()
                
                YouTubeStatusSection(
                    youtubeURL: youtubeURL,
                    importManager: importManager,
                    showingTimeSelector: showingTimeSelector,
                    isProcessing: isProcessing,
                    isFetchingVideoInfo: isFetchingVideoInfo  // NEW: Pass loading state
                )
                
                if importManager.downloadedVideoURL == nil {
                    YouTubeURLInputSection(
                        youtubeURL: $youtubeURL,
                        importManager: importManager,
                        onFetchVideoInfo: fetchVideoInfo,
                        isProcessing: isProcessing,
                        isFetchingVideoInfo: isFetchingVideoInfo
                    )
                } else {
                    YouTubeVideoPreviewSection(videoURL: importManager.downloadedVideoURL!)
                }
                
                // ✅ A v YouTubeImportView.swift předejte isProcessing parametr:

                if showingVideoInfo {
                    YouTubeVideoInfoSection(
                        importManager: importManager,
                        onDownloadVideo: downloadVideo,
                        onCancelDownload: { importManager.cancelDownload() },
                        isProcessing: isProcessing  // ✅ PŘIDÁNO
                    )
                }
                
                if showingTimeSelector {
                    YouTubeTimeSelectorSection(
                        importManager: importManager
                    )
                }
                
                if isProcessing {
                    YouTubeProcessingSection(
                        progress: processingProgress,
                        message: processingMessage
                    )
                }
                
                YouTubeActionButtonsSection(
                    showingTimeSelector: showingTimeSelector,
                    hasDownloadedVideo: importManager.downloadedVideoURL != nil,
                    isProcessing: isProcessing,
                    onProcessVideo: processVideo,
                    onStartOver: resetImport
                )
            }
            .padding(30)
        }
        .onAppear {
            checkDependencies()
        }
        .alert("Missing Dependencies", isPresented: $showingDependencyAlert) {
            Button("OK") { }
        } message: {
            Text(dependencyMessage)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    // Existing buttons...
                    
                    // NOVÝ: Diagnostics button
                    Button(action: {
                        showingDiagnostics = true
                    }) {
                        HStack {
                            Image(systemName: "stethoscope")
                            Text("Diagnostics")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        
        // Přidejte do YouTubeImportView.swift (do toolbar section)

        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button(action: {
                        showingDiagnostics = true
                    }) {
                        HStack {
                            Image(systemName: "stethoscope")
                            Text("Diagnostics")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }

        // Přidejte do View body (sheet modifiers)
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsView(
                report: $diagnosticsReport,
                onRunDiagnostics: {
                    Task {
                        await runDiagnostics()
                    }
                }
            )
        }
    }
    
    
    private func runDiagnostics() async {
        print("🩺 Running comprehensive diagnostics...")
        
        var report = "🩺 WallMotion YouTube Import Diagnostics\n"
        report += "==========================================\n\n"
        
        // 1. Dependencies check
        let deps = importManager.dependenciesManager.checkDependencies()
        report += "📋 Dependencies Status:\n"
        report += "• Homebrew: \(deps.homebrew ? "✅" : "❌")\n"
        report += "• yt-dlp: \(deps.ytdlp ? "✅" : "❌")\n"
        report += "• ffmpeg: \(deps.ffmpeg ? "✅" : "❌")\n\n"
        
        // 2. Bundle analysis
        if let resourcePath = Bundle.main.resourcePath {
            report += "📁 Bundle Analysis:\n"
            report += "• Resource path: \(resourcePath)\n"
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                report += "• Bundle contents: \(contents.joined(separator: ", "))\n"
            } catch {
                report += "• Error reading bundle: \(error)\n"
            }
            
            // Check specific tools
            for tool in ["yt-dlp", "ffmpeg", "ffprobe"] {
                let toolPath = "\(resourcePath)/\(tool)"
                let exists = FileManager.default.fileExists(atPath: toolPath)
                let executable = FileManager.default.isExecutableFile(atPath: toolPath)
                report += "• \(tool): \(exists ? "✅ exists" : "❌ missing"), \(executable ? "✅ executable" : "❌ not executable")\n"
            }
            report += "\n"
        }
        
        // 3. Tool testing
        let toolTestResult = await importManager.testBundledTools()
        report += "🧪 Tool Testing:\n"
        report += toolTestResult.details
        
        // 4. Environment
        report += "🌍 Environment:\n"
        report += "• PATH: \(ProcessInfo.processInfo.environment["PATH"] ?? "Not set")\n"
        report += "• Temp dir: \(FileManager.default.temporaryDirectory.path)\n"
        report += "• App sandbox: \(isSandboxed() ? "✅ Active" : "❌ Disabled")\n"
        
        await MainActor.run {
            diagnosticsReport = report
            print("🩺 Diagnostics complete")
        }
    }

    private func isSandboxed() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    // MARK: - Private Methods
    
    private func checkDependencies() {
        let deps = importManager.checkDependencies()
        if !deps.ytdlp || !deps.ffmpeg {
            dependencyMessage = importManager.installationInstructions()
            showingDependencyAlert = true
        }
    }
    
    private func fetchVideoInfo() {
        guard !isProcessing && !isFetchingVideoInfo else { return }
        
        print("🔍 User requested video info for: \(youtubeURL)")
        
        isFetchingVideoInfo = true
        
        Task {
            do {
                let info = try await importManager.getVideoInfo(from: youtubeURL)
                await MainActor.run {
                    // Set correct max duration based on video length (max 5 minutes for wallpaper)
                    importManager.maxDuration = min(info.duration, 300.0)
                    
                    // Reset time selection to reasonable defaults
                    importManager.selectedStartTime = 0.0
                    importManager.selectedEndTime = min(30.0, info.duration)
                    
                    importManager.videoInfo = info
                    isFetchingVideoInfo = false
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingVideoInfo = true
                    }
                    
                    print("✅ Video info loaded: \(info.title)")
                    print("   📊 Duration: \(info.duration)s")
                    print("   📊 Max selectable: \(importManager.maxDuration)s")
                    print("   📊 Default selection: \(importManager.selectedStartTime)s - \(importManager.selectedEndTime)s")
                }
            } catch {
                await MainActor.run {
                    isFetchingVideoInfo = false
                    print("❌ Failed to fetch video info: \(error)")
                    if let ytError = error as? YouTubeError {
                        print("   YouTube Error: \(ytError.errorDescription ?? "Unknown")")
                        dependencyMessage = ytError.errorDescription ?? "Failed to fetch video info"
                        showingDependencyAlert = true
                    }
                }
            }
        }
    }
    
    private func downloadVideo() {
        guard !isProcessing else { return }
        
        print("📥 User initiated download for: \(youtubeURL)")
        
        // ✅ NASTAVIT isProcessing = true HNED NA ZAČÁTKU
        isProcessing = true
        processingProgress = 0.0
        processingMessage = "Starting download..."
        
        Task {
            do {
                _ = try await importManager.downloadVideo(from: youtubeURL) { progress, message in
                    DispatchQueue.main.async {
                        processingProgress = progress
                        processingMessage = message
                        print("📊 Download progress: \(Int(progress * 100))% - \(message)")
                        
                        // ❌ ODSTRAŇTE TENTO BLOK - resetuje isProcessing příliš brzy
                        // if message.contains("successfully") || message.contains("completed") {
                        //     isProcessing = false
                        // }
                    }
                }
                
                await MainActor.run {
                    // ✅ RESETUJ isProcessing AŽ TADY - po dokončení celé downloadVideo funkce
                    isProcessing = false
                    print("✅ Download + conversion completed")
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingVideoInfo = false
                        showingTimeSelector = true
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    print("❌ Download failed: \(error)")
                    if let ytError = error as? YouTubeError {
                        print("   YouTube Error: \(ytError.errorDescription ?? "Unknown")")
                        dependencyMessage = ytError.errorDescription ?? "Download failed"
                        showingDependencyAlert = true
                    }
                }
            }
        }
    }

    private func processVideo() {
        guard !isProcessing else { return }
        guard let inputURL = importManager.downloadedVideoURL else {
            print("❌ No input video URL available")
            return
        }
        
        print("⚙️ User initiated video processing")
        print("   📁 Input: \(inputURL.path)")
        print("   ⏰ Range: \(importManager.selectedStartTime)s - \(importManager.selectedEndTime)s")
        print("   ⏰ Duration: \(importManager.selectedEndTime - importManager.selectedStartTime)s")
        
        isProcessing = true
        processingProgress = 0.0
        processingMessage = "Processing video segment..."
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wallpaper_trimmed_\(UUID().uuidString).mov")
        
        print("   📁 Output will be: \(outputURL.path)")
        
        Task {
            do {
                try await importManager.trimVideo(
                    inputURL,
                    startTime: importManager.selectedStartTime,
                    endTime: importManager.selectedEndTime,
                    outputPath: outputURL
                )
                
                await MainActor.run {
                    isProcessing = false
                    print("✅ Video processing completed: \(outputURL.path)")
                    onVideoReady(outputURL)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    print("❌ Video processing failed: \(error)")
                    if let ytError = error as? YouTubeError {
                        dependencyMessage = ytError.errorDescription ?? "Processing failed"
                        showingDependencyAlert = true
                    }
                }
            }
        }
    }
    
    private func resetImport() {
        guard !isProcessing && !isFetchingVideoInfo else { return }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            importManager.cleanup()
            youtubeURL = ""
            showingVideoInfo = false
            showingTimeSelector = false
            isProcessing = false
            processingProgress = 0.0
            processingMessage = ""
            isFetchingVideoInfo = false
        }
    }
}


// MARK: - Complete DiagnosticsView for macOS
struct DiagnosticsView: View {
    @Binding var report: String
    let onRunDiagnostics: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var isRunning = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("YouTube Import Diagnostics")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !report.isEmpty && !isRunning {
                    Menu {
                        Button("Copy Full Report") {
                            copyToClipboard(report)
                        }
                        
                        Button("Save to File") {
                            saveReportToFile()
                        }
                        
                        Divider()
                        
                        Button("Clear Report") {
                            withAnimation {
                                report = ""
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                } else {
                    // Invisible placeholder for spacing
                    Button("") { }
                        .disabled(true)
                        .opacity(0)
                        .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main Content Area
            if report.isEmpty && !isRunning {
                emptyStateView
            } else if isRunning {
                runningStateView
            } else {
                reportView
            }
        }
        .frame(width: 800, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "stethoscope.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)
            
            // Title
            Text("Run Diagnostics")
                .font(.title)
                .fontWeight(.semibold)
            
            // Description
            VStack(spacing: 8) {
                Text("This diagnostic tool will check:")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Bundled executables (yt-dlp, ffmpeg, ffprobe)")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("File permissions and quarantine status")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("System dependencies and paths")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Environment configuration")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Run Button
            Button(action: {
                runDiagnostics()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Run Diagnostics")
                }
                .font(.body)
                .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return)
            
            Spacer()
        }
        .padding(40)
    }
    
    // MARK: - Running State View
    private var runningStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(.circular)
            
            Text("Running diagnostics...")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Checking dependencies and bundled tools")
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Report View
    private var reportView: some View {
        VStack(spacing: 0) {
            // Report header with status
            HStack {
                let success = report.contains("SUCCESS")
                let hasErrors = report.contains("❌") || report.contains("ERROR")
                
                HStack(spacing: 8) {
                    Image(systemName: success && !hasErrors ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(success && !hasErrors ? .green : .orange)
                    
                    Text(success && !hasErrors ? "Diagnostics Passed" : "Issues Found")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Run Again") {
                        runDiagnostics()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Copy Report") {
                        copyToClipboard(report)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("c", modifiers: .command)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Scrollable report content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(report)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }
    
    // MARK: - Actions
    private func runDiagnostics() {
        withAnimation {
            isRunning = true
            report = ""
        }
        
        Task {
            // Add delay to show loading state
            try? await Task.sleep(for: .seconds(0.5))
            
            await onRunDiagnostics()
            
            await MainActor.run {
                withAnimation {
                    isRunning = false
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Optional: Show confirmation
        print("📋 Report copied to clipboard")
    }
    
    private func saveReportToFile() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "wallmotion-diagnostics-\(Date().formatted(.iso8601.day().month().year())).txt"
        savePanel.title = "Save Diagnostics Report"
        
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                do {
                    try report.write(to: url, atomically: true, encoding: .utf8)
                    print("📄 Report saved to: \(url.path)")
                } catch {
                    print("❌ Failed to save report: \(error)")
                }
            }
        }
    }
}
