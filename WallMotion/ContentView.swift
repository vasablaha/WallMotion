import SwiftUI
import AVKit
import Foundation
import Combine

// MARK: - Smart WallpaperManager (inside ContentView.swift)
class WallpaperManager: ObservableObject {
    @Published var availableWallpapers: [String] = []
    @Published var detectedWallpaper: String = ""
    
    private let wallpaperPath = "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"
    
    init() {
        print("🚀 WallpaperManager: Smart detection initialized")
        detectCurrentWallpaper()
    }
    
    func detectCurrentWallpaper() {
        print("🔍 Detecting currently set wallpaper...")
        print("📂 Scanning: \(wallpaperPath)")
        
        guard FileManager.default.fileExists(atPath: wallpaperPath) else {
            print("❌ Wallpaper folder not found: \(wallpaperPath)")
            print("💡 Please set an underwater wallpaper first!")
            detectedWallpaper = "No wallpaper detected - please set one first"
            availableWallpapers = []
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: wallpaperPath)
            let movFiles = files.filter { $0.hasSuffix(".mov") }
            
            print("📄 Found \(movFiles.count) .mov files in folder")
            
            if movFiles.isEmpty {
                print("⚠️ No .mov files found")
                print("💡 Set an underwater wallpaper in System Settings first!")
                detectedWallpaper = "No wallpapers downloaded - set one first"
                availableWallpapers = []
                return
            }
            
            // Find newest file by modification date
            var newestFile: String = ""
            var newestDate: Date = Date.distantPast
            
            for file in movFiles {
                let filePath = "\(wallpaperPath)/\(file)"
                let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
                
                if let modDate = attributes[.modificationDate] as? Date {
                    print("📅 \(file): \(modDate)")
                    
                    if modDate > newestDate {
                        newestDate = modDate
                        newestFile = file
                    }
                }
            }
            
            if !newestFile.isEmpty {
                let wallpaperName = newestFile.replacingOccurrences(of: ".mov", with: "")
                detectedWallpaper = wallpaperName
                availableWallpapers = [wallpaperName]
                
                print("✅ Detected current wallpaper: \(wallpaperName)")
                print("📅 Last modified: \(newestDate)")
                print("📁 File: \(newestFile)")
            } else {
                print("❌ Could not determine newest file")
                detectedWallpaper = "Detection failed"
                availableWallpapers = []
            }
            
        } catch {
            print("❌ Error scanning wallpaper folder: \(error.localizedDescription)")
            detectedWallpaper = "Error: \(error.localizedDescription)"
            availableWallpapers = []
        }
    }
    
    func replaceWallpaper(
        videoURL: URL,
        progressCallback: @escaping (Double, String) -> Void
    ) async {
        
        print("🎬 Starting smart wallpaper replacement...")
        print("📹 Source video: \(videoURL.path)")
        
        progressCallback(0.1, "Detecting current wallpaper...")
        
        // Re-detect to get the most current wallpaper
        await MainActor.run {
            detectCurrentWallpaper()
        }
        
        guard !detectedWallpaper.isEmpty && !detectedWallpaper.contains("No wallpaper") && !detectedWallpaper.contains("Error") else {
            progressCallback(0.0, "❌ No wallpaper detected. Set an underwater wallpaper first!")
            return
        }
        
        let targetFileName = "\(detectedWallpaper).mov"
        let targetPath = "\(wallpaperPath)/\(targetFileName)"
        
        print("🎯 Target file: \(targetFileName)")
        print("📍 Full path: \(targetPath)")
        
        progressCallback(0.2, "Preparing video...")
        
        // First copy to temp location (app has access to temp)
        let tempDir = FileManager.default.temporaryDirectory
        let tempVideoPath = tempDir.appendingPathComponent("wallpaper_temp.mov").path
        let backupPath = "\(targetPath).backup.\(Int(Date().timeIntervalSince1970))"
        
        print("📁 Copying to temp location: \(tempVideoPath)")
        
        do {
            // Copy to temp using FileManager (no sudo needed)
            try FileManager.default.copyItem(atPath: videoURL.path, toPath: tempVideoPath)
            print("✅ Video copied to temp location")
        } catch {
            print("❌ Failed to copy to temp: \(error)")
            progressCallback(0.0, "❌ Failed to prepare video")
            return
        }
        
        progressCallback(0.4, "Requesting admin access (ONE TIME ONLY)...")
        
        // Execute ALL commands in one admin request!
        guard await executeAllCommands(tempVideoPath: tempVideoPath, targetPath: targetPath, backupPath: backupPath, progressCallback: progressCallback) else {
            // Cleanup temp file
            try? FileManager.default.removeItem(atPath: tempVideoPath)
            progressCallback(0.0, "❌ Installation failed")
            return
        }
        
        // Cleanup temp file
        try? FileManager.default.removeItem(atPath: tempVideoPath)
        print("🧹 Cleaned up temp file")
        
        progressCallback(1.0, "✅ Wallpaper replaced! Check System Settings!")
        print("🎉 Replacement completed successfully!")
    }
    
    private func executeAllCommands(tempVideoPath: String, targetPath: String, backupPath: String) async -> Bool {
        print("🔐 Requesting admin privileges for batch operation...")
        
        let batchScript = """
        do shell script "
        echo '🔄 Starting batch wallpaper replacement...'
        
        # Step 1: Backup original
        echo '💾 Backing up original...'
        cp '\(targetPath)' '\(backupPath)'
        
        # Step 2: Remove original
        echo '🗑️ Removing original...'
        rm '\(targetPath)'
        
        # Step 3: Install new video
        echo '📦 Installing new video...'
        cp '\(tempVideoPath)' '\(targetPath)'
        
        # Step 4: Refresh system
        echo '🔄 Refreshing wallpaper system...'
        killall WallpaperAgent 2>/dev/null || true
        
        echo '✅ Batch operation completed!'
        " with administrator privileges
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let appleScript = NSAppleScript(source: batchScript)
                var error: NSDictionary?
                let result = appleScript?.executeAndReturnError(&error)
                
                if let error = error {
                    print("❌ Batch operation failed: \(error)")
                    continuation.resume(returning: false)
                } else {
                    print("✅ Batch operation succeeded!")
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    // Single batch operation - no more multiple admin requests!
    private func executeAllCommands(tempVideoPath: String, targetPath: String, backupPath: String, progressCallback: @escaping (Double, String) -> Void) async -> Bool {
        print("🔐 Requesting admin privileges for batch operation...")
        
        // Show intermediate progress during batch operation
        await MainActor.run {
            progressCallback(0.5, "Backing up original...")
        }
        
        let batchScript = """
        do shell script "
        echo '🔄 Starting batch wallpaper replacement...'
        
        # Step 1: Backup original
        echo '💾 Backing up original...'
        cp '\(targetPath)' '\(backupPath)'
        
        # Step 2: Remove original
        echo '🗑️ Removing original...'
        rm '\(targetPath)'
        
        # Step 3: Install new video
        echo '📦 Installing new video...'
        cp '\(tempVideoPath)' '\(targetPath)'
        
        # Step 4: Refresh system
        echo '🔄 Refreshing wallpaper system...'
        killall WallpaperAgent 2>/dev/null || true
        
        echo '✅ Batch operation completed!'
        " with administrator privileges
        """
        
        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let appleScript = NSAppleScript(source: batchScript)
                var error: NSDictionary?
                let result = appleScript?.executeAndReturnError(&error)
                
                if let error = error {
                    print("❌ Batch operation failed: \(error)")
                    continuation.resume(returning: false)
                } else {
                    print("✅ Batch operation succeeded!")
                    continuation.resume(returning: true)
                }
            }
        }
        
        if success {
            await MainActor.run {
                progressCallback(0.9, "Refreshing system...")
            }
        }
        
        return success
    }
}

// MARK: - Main ContentView
struct ContentView: View {
    @StateObject private var wallpaperManager = WallpaperManager()
    @State private var selectedVideoURL: URL?
    @State private var isProcessing = false
    @State private var progress: Double = 0.0
    @State private var statusMessage = "Ready to replace wallpaper"
    @State private var showingFilePicker = false
    
    var body: some View {
        VStack(spacing: 30) {
            headerView
            
            Divider()
            
            detectionSection
            
            Divider()
            
            videoSelectionSection
            
            Divider()
            
            progressSection
            
            actionButtonSection
            
            Spacer()
            
            debugSection
        }
        .padding(40)
        .frame(width: 800, height: 700)
        .background(Color(.windowBackgroundColor))
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.movie, .quickTimeMovie, .mpeg4Movie],
            allowsMultipleSelection: false
        ) { result in
            handleVideoSelection(result)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 15) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 70))
                .foregroundColor(.blue)
            
            Text("WallMotion")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Smart wallpaper replacement - automatically detects your current wallpaper")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var detectionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Current Wallpaper Detection")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Refresh Detection") {
                    print("🔄 Manual refresh requested")
                    wallpaperManager.detectCurrentWallpaper()
                }
                .buttonStyle(.bordered)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    if wallpaperManager.detectedWallpaper.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Detecting wallpaper...")
                                .foregroundColor(.secondary)
                        }
                    } else if wallpaperManager.detectedWallpaper.contains("No wallpaper") || wallpaperManager.detectedWallpaper.contains("Error") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text(wallpaperManager.detectedWallpaper)
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }
                            
                            Divider()
                            
                            Text("How to fix:")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("1. Open System Settings → Wallpaper")
                                Text("2. Choose 'Underwater' category")
                                Text("3. Select any underwater wallpaper (e.g., Alaskan Jellyfish)")
                                Text("4. Wait for download to complete")
                                Text("5. Click 'Refresh Detection' button above")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Detected: \(wallpaperManager.detectedWallpaper)")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            
                            Text("✅ Ready for replacement!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
            }
        }
    }
    
    private var videoSelectionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Select Your Video")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                Button(action: { showingFilePicker = true }) {
                    HStack {
                        Image(systemName: "video.badge.plus")
                        Text("Choose Video File")
                    }
                    .padding(.horizontal)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                if let url = selectedVideoURL {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("✅ \(url.lastPathComponent)")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                        Text(url.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                } else {
                    Text("No video selected")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var progressSection: some View {
        VStack(spacing: 15) {
            if isProcessing {
                ProgressView(value: progress) {
                    Text("Processing...")
                }
                .progressViewStyle(LinearProgressViewStyle())
            }
            
            Text(statusMessage)
                .font(.headline)
                .foregroundColor(isProcessing ? .orange : (statusMessage.contains("✅") ? .green : .primary))
                .multilineTextAlignment(.center)
        }
    }
    
    private var actionButtonSection: some View {
        Button(action: replaceWallpaper) {
            HStack {
                Image(systemName: isProcessing ? "gear" : "arrow.triangle.2.circlepath")
                    .rotationEffect(.degrees(isProcessing ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isProcessing)
                
                Text(isProcessing ? "Processing..." : "Replace Wallpaper")
                    .font(.headline)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(selectedVideoURL == nil ||
                 wallpaperManager.detectedWallpaper.isEmpty ||
                 wallpaperManager.detectedWallpaper.contains("No wallpaper") ||
                 wallpaperManager.detectedWallpaper.contains("Error") ||
                 isProcessing)
    }
    
    private var debugSection: some View {
        GroupBox("Debug Info") {
            VStack(alignment: .leading, spacing: 5) {
                Text("Video: \(selectedVideoURL?.lastPathComponent ?? "None")")
                Text("Detected: \(wallpaperManager.detectedWallpaper.isEmpty ? "None" : wallpaperManager.detectedWallpaper)")
                Text("Wallpaper Path: /Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func handleVideoSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                selectedVideoURL = url
                print("✅ Video selected: \(url.path)")
                statusMessage = "Video ready: \(url.lastPathComponent)"
            }
        case .failure(let error):
            print("❌ Video selection error: \(error)")
            statusMessage = "❌ Failed to select video"
        }
    }
    
    private func replaceWallpaper() {
        guard let videoURL = selectedVideoURL else { return }
        
        print("🚀 Starting smart replacement...")
        print("🎯 Detected wallpaper: \(wallpaperManager.detectedWallpaper)")
        print("📹 Video source: \(videoURL.path)")
        
        isProcessing = true
        progress = 0.0
        
        Task {
            await wallpaperManager.replaceWallpaper(videoURL: videoURL) { progressValue, message in
                DispatchQueue.main.async {
                    self.progress = progressValue
                    self.statusMessage = message
                    
                    if progressValue >= 1.0 {
                        self.isProcessing = false
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
