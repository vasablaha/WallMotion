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
    @State private var isAnalyzing = false

    
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
                    OptimizedYouTubeVideoPreviewSection(videoURL: importManager.downloadedVideoURL!)
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
        
        isProcessing = true
        isAnalyzing = false  // ✅ Reset analyzing state
        processingProgress = 0.0
        processingMessage = "Starting download..."
        
        Task {
            do {
                _ = try await importManager.downloadVideo(from: youtubeURL) { progress, message in
                    DispatchQueue.main.async {
                        // ✅ SPRÁVNÉ rozlišování mezi stahováním a analýzou
                        if progress < 0 {
                            // -1 znamená nekonečný spinner (analýza/konverze)
                            self.isAnalyzing = true
                            self.processingProgress = 0.5  // Statický progress pro spinner
                            self.processingMessage = message
                        } else {
                            // Normální progress stahování
                            self.isAnalyzing = false
                            self.processingProgress = progress
                            self.processingMessage = message
                        }
                        
                        print("📊 Progress: \(progress >= 0 ? "\(Int(progress * 100))%" : "analyzing") - \(message)")
                    }
                }
                
                await MainActor.run {
                    isProcessing = false
                    isAnalyzing = false  // ✅ Reset na konci
                    print("✅ Download + conversion completed")
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingVideoInfo = false
                        showingTimeSelector = true
                    }
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    isAnalyzing = false  // ✅ Reset při chybě
                    print("❌ Download failed: \(error)")
                    if let ytError = error as? YouTubeError {
                        dependencyMessage = ytError.errorDescription ?? "Download failed"
                        showingDependencyAlert = true
                    }
                }
            }
        }
    }
    
    private func processVideo() {
        guard !isProcessing else { return }
        
        // ✅ KONTROLA že downloadedVideoURL je nastavena
        guard let inputURL = importManager.downloadedVideoURL else {
            print("❌ No input video URL available")
            print("🔍 Debug info:")
            print("   isDownloading: \(importManager.isDownloading)")
            print("   downloadProgress: \(importManager.downloadProgress)")
            print("   downloadedVideoURL: \(importManager.downloadedVideoURL?.path ?? "nil")")
            
            // ✅ Zobrazit uživateli lepší chybu
            dependencyMessage = "Video není připraveno. Zkuste stáhnout video znovu nebo restartovat aplikaci."
            showingDependencyAlert = true
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
                    } else {
                        dependencyMessage = "Video processing failed: \(error.localizedDescription)"
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
