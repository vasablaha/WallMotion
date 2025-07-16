//
//  YouTubeImportView.swift
//  WallMotion
//
//  Main YouTube Import View - Final version
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
    
    let onVideoReady: (URL) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                YouTubeImportHeader()
                
                YouTubeStatusSection(
                    youtubeURL: youtubeURL,
                    importManager: importManager,
                    showingTimeSelector: showingTimeSelector,
                    isProcessing: isProcessing
                )
                
                if importManager.downloadedVideoURL == nil {
                    YouTubeURLInputSection(
                        youtubeURL: $youtubeURL,
                        importManager: importManager,
                        onFetchVideoInfo: fetchVideoInfo,
                        isProcessing: isProcessing
                    )
                } else {
                    YouTubeVideoPreviewSection(
                        videoURL: importManager.downloadedVideoURL!
                    )
                }
                
                if showingVideoInfo {
                    YouTubeVideoInfoSection(
                        importManager: importManager,
                        onDownloadVideo: downloadVideo,
                        onCancelDownload: { importManager.cancelDownload() }
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
                
                YouTubeDebugInfoSection(importManager: importManager)
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
        guard !isProcessing else { return }
        
        print("🔍 User requested video info for: \(youtubeURL)")
        
        Task {
            do {
                let info = try await importManager.getVideoInfo(from: youtubeURL)
                await MainActor.run {
                    importManager.videoInfo = info
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingVideoInfo = true
                    }
                    print("✅ Video info loaded: \(info.title)")
                }
            } catch {
                await MainActor.run {
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
        
        Task {
            do {
                _ = try await importManager.downloadVideo(from: youtubeURL) { progress, message in
                    DispatchQueue.main.async {
                        processingProgress = progress
                        processingMessage = message
                        print("📊 Download progress: \(Int(progress * 100))% - \(message)")
                    }
                }
                
                await MainActor.run {
                    print("✅ Download completed")
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingVideoInfo = false
                        showingTimeSelector = true
                    }
                }
            } catch {
                await MainActor.run {
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
        
        isProcessing = true
        processingProgress = 0.0
        processingMessage = "Processing video segment..."
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wallpaper_trimmed_\(UUID().uuidString).mov")
        
        print("   📁 Output will be: \(outputURL.path)")
        
        Task {
            do {
                try await importManager.trimVideo(
                    inputURL: inputURL,
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
        guard !isProcessing else { return }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            importManager.cleanup()
            youtubeURL = ""
            showingVideoInfo = false
            showingTimeSelector = false
            isProcessing = false
            processingProgress = 0.0
            processingMessage = ""
        }
    }
}

#Preview {
    YouTubeImportView { url in
        print("Video ready: \(url)")
    }
    .frame(width: 500, height: 700)
}
