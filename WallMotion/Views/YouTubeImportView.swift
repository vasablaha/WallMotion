//
//  YouTubeImportView.swift
//  WallMotion
//
//  YouTube video import UI component - Updated Design
//

import SwiftUI
import AVKit

struct YouTubeImportView: View {
    @StateObject private var importManager = YouTubeImportManager()
    @State private var youtubeURL = ""
    @State private var showingDependencyAlert = false
    @State private var dependencyMessage = ""
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0.0
    @State private var processingMessage = ""
    
    let onVideoReady: (URL) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                if importManager.downloadedVideoURL == nil {
                    urlInputSection
                    if importManager.videoInfo != nil {
                        videoInfoSection
                    }
                } else {
                    videoDownloadedSection
                    timeSelectorSection
                }
                
                if isProcessing {
                    processingSection
                }
                
                actionButtonsSection
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("YouTube Import")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            Text("Download and customize any YouTube video as your wallpaper")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - URL Input Section
    
    private var urlInputSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("YouTube Video URL")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 12) {
                    TextField("https://youtube.com/watch?v=...", text: $youtubeURL)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            if importManager.validateYouTubeURL(youtubeURL) {
                                fetchVideoInfo()
                            }
                        }
                    
                    Button(action: fetchVideoInfo) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                            Text("Get Info")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(youtubeURL.isEmpty || !importManager.validateYouTubeURL(youtubeURL))
                }
                
                // URL validation feedback
                if !youtubeURL.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: importManager.validateYouTubeURL(youtubeURL) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(importManager.validateYouTubeURL(youtubeURL) ? .green : .red)
                        
                        Text(importManager.validateYouTubeURL(youtubeURL) ? "Valid YouTube URL" : "Invalid YouTube URL")
                            .font(.caption)
                            .foregroundColor(importManager.validateYouTubeURL(youtubeURL) ? .green : .red)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Video Info Section
    
    private var videoInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let videoInfo = importManager.videoInfo {
                HStack(spacing: 16) {
                    // Thumbnail
                    AsyncImage(url: URL(string: videoInfo.thumbnail)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                    .frame(width: 120, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(videoInfo.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(3)
                        
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text(formatDuration(videoInfo.duration))
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "video")
                                    .font(.caption)
                                Text(videoInfo.quality)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                // Download progress or button
                if importManager.isDownloading {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Downloading...")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(Int(importManager.downloadProgress * 100))%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        
                        ProgressView(value: importManager.downloadProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        
                        Button("Cancel") {
                            importManager.cancelDownload()
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                    }
                } else {
                    Button(action: downloadVideo) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Video")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Video Downloaded Section
    
    private var videoDownloadedSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Video Downloaded!")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    if let videoURL = importManager.downloadedVideoURL {
                        Text(videoURL.lastPathComponent)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            
            // Simple video preview (without player controls)
            if let videoURL = importManager.downloadedVideoURL {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.1))
                    .frame(height: 160)
                    .overlay(
                        VStack {
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white.opacity(0.8))
                            Text("Video Ready")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Time Selector Section (Fixed)
    
    private var timeSelectorSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Wallpaper Duration")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Choose the portion of video you want as wallpaper")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                // Duration info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start Time")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(formatTime(safeStartTime))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("Duration")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(formatTime(safeEndTime - safeStartTime))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("End Time")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(formatTime(safeEndTime))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 4)
                
                // Fixed range sliders with proper bounds
                VStack(spacing: 12) {
                    Text("Drag to select time range (recommended: 30-60 seconds)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 8) {
                        Text("Start: \(formatTime(safeStartTime))")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Slider(
                            value: Binding(
                                get: { safeStartTime },
                                set: { newValue in
                                    let clampedStart = max(0, min(newValue, safeMaxDuration - 10))
                                    importManager.selectedStartTime = clampedStart
                                    
                                    // Ensure end time is always at least 10 seconds after start
                                    if importManager.selectedEndTime < clampedStart + 10 {
                                        importManager.selectedEndTime = min(clampedStart + 30, safeMaxDuration)
                                    }
                                }
                            ),
                            in: 0...max(0, safeMaxDuration - 10),
                            step: 1
                        )
                        .accentColor(.blue)
                    }
                    
                    VStack(spacing: 8) {
                        Text("End: \(formatTime(safeEndTime))")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Slider(
                            value: Binding(
                                get: { safeEndTime },
                                set: { newValue in
                                    let minEnd = safeStartTime + 10
                                    let clampedEnd = max(minEnd, min(newValue, safeMaxDuration))
                                    importManager.selectedEndTime = clampedEnd
                                }
                            ),
                            in: max(10, safeStartTime + 10)...safeMaxDuration,
                            step: 1
                        )
                        .accentColor(.blue)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    // MARK: - Safe computed properties to prevent SwiftUI bugs
    
    private var safeMaxDuration: Double {
        max(30, importManager.maxDuration.rounded())
    }
    
    private var safeStartTime: Double {
        max(0, min(importManager.selectedStartTime.rounded(), safeMaxDuration - 10))
    }
    
    private var safeEndTime: Double {
        let minEnd = safeStartTime + 10
        let maxEnd = safeMaxDuration
        return max(minEnd, min(importManager.selectedEndTime.rounded(), maxEnd))
    }
    
    // MARK: - Processing Section
    
    private var processingSection: some View {
        VStack(spacing: 16) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text(processingMessage)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(processingProgress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: processingProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            if importManager.downloadedVideoURL != nil && !isProcessing {
                Button("Process & Use Video") {
                    processVideo()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .green.opacity(0.3), radius: 8)
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessing)
                
                Button("Start Over") {
                    resetImport()
                }
                .font(.headline)
                .foregroundColor(.red)
                .frame(width: 120)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.red, lineWidth: 2)
                )
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessing)
            }
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
        print("🔍 User requested video info for: \(youtubeURL)")
        
        Task {
            do {
                let info = try await importManager.getVideoInfo(from: youtubeURL)
                await MainActor.run {
                    importManager.videoInfo = info
                    print("✅ Video info loaded: \(info.title)")
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to fetch video info: \(error)")
                    if let ytError = error as? YouTubeError {
                        print("   YouTube Error: \(ytError.errorDescription ?? "Unknown")")
                        dependencyMessage = ytError.errorDescription ?? "Failed to get video info"
                        showingDependencyAlert = true
                    }
                }
            }
        }
    }
    
    private func downloadVideo() {
        print("📥 User initiated download for: \(youtubeURL)")
        
        Task {
            do {
                let videoURL = try await importManager.downloadVideo(from: youtubeURL) { progress, message in
                    DispatchQueue.main.async {
                        importManager.downloadProgress = progress
                        print("📊 Download progress: \(Int(progress * 100))% - \(message)")
                    }
                }
                
                await MainActor.run {
                    print("✅ Download completed: \(videoURL.path)")
                    // Initialize time selector with reasonable defaults
                    importManager.selectedStartTime = 0.0
                    importManager.selectedEndTime = min(30.0, importManager.maxDuration)
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
        guard let inputURL = importManager.downloadedVideoURL else {
            print("❌ No input video URL available")
            return
        }
        
        // Use safe values to prevent bounds errors
        let startTime = safeStartTime
        let endTime = safeEndTime
        
        print("⚙️ User initiated video processing")
        print("   📁 Input: \(inputURL.path)")
        print("   ⏰ Range: \(startTime)s - \(endTime)s")
        
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
                    startTime: startTime,
                    endTime: endTime,
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            importManager.cleanup()
            youtubeURL = ""
            isProcessing = false
            processingProgress = 0.0
            processingMessage = ""
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    YouTubeImportView { url in
        print("Video ready: \(url)")
    }
    .frame(width: 500, height: 700)
}
