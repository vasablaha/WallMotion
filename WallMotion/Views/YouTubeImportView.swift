//
//  YouTubeImportView.swift
//  WallMotion
//
//  YouTube video import UI component
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
        VStack(spacing: 24) {
            headerSection
            
            // Current Status Indicator
            currentStatusSection
            
            if importManager.downloadedVideoURL == nil {
                urlInputSection
            } else {
                videoPreviewSection
            }
            
            if showingVideoInfo {
                videoInfoSection
            }
            
            if showingTimeSelector {
                timeSelectorSection
            }
            
            if isProcessing {
                processingSection
            }
            
            actionButtonsSection
            
            Spacer()
        }
        .padding(30)
        .onAppear {
            checkDependencies()
        }
        .alert("Missing Dependencies", isPresented: $showingDependencyAlert) {
            Button("OK") { }
        } message: {
            Text(dependencyMessage)
        }
    }
    
    // MARK: - Current Status Section
    
    private var currentStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Current Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 16) {
                // Step 1: URL Input
                StatusStep(
                    icon: "link",
                    title: "URL",
                    isCompleted: !youtubeURL.isEmpty && importManager.validateYouTubeURL(youtubeURL),
                    isCurrent: youtubeURL.isEmpty || !importManager.validateYouTubeURL(youtubeURL)
                )
                
                StatusConnector()
                
                // Step 2: Video Info
                StatusStep(
                    icon: "info.circle",
                    title: "Info",
                    isCompleted: importManager.videoInfo != nil,
                    isCurrent: !youtubeURL.isEmpty && importManager.validateYouTubeURL(youtubeURL) && importManager.videoInfo == nil
                )
                
                StatusConnector()
                
                // Step 3: Download
                StatusStep(
                    icon: "arrow.down.circle",
                    title: "Download",
                    isCompleted: importManager.downloadedVideoURL != nil,
                    isCurrent: importManager.isDownloading
                )
                
                StatusConnector()
                
                // Step 4: Trim
                StatusStep(
                    icon: "scissors",
                    title: "Trim",
                    isCompleted: false,
                    isCurrent: importManager.downloadedVideoURL != nil && !isProcessing
                )
                
                StatusConnector()
                
                // Step 5: Ready
                StatusStep(
                    icon: "checkmark.circle",
                    title: "Ready",
                    isCompleted: false,
                    isCurrent: isProcessing
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.gray.opacity(0.2), lineWidth: 1)
                )
        )
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
            VStack(alignment: .leading, spacing: 8) {
                Text("YouTube Video URL")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack {
                    TextField("https://youtube.com/watch?v=...", text: $youtubeURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            if importManager.validateYouTubeURL(youtubeURL) {
                                fetchVideoInfo()
                            }
                        }
                    
                    Button(action: fetchVideoInfo) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(.blue))
                    }
                    .disabled(youtubeURL.isEmpty || !importManager.validateYouTubeURL(youtubeURL))
                }
            }
            
            // URL validation feedback
            if !youtubeURL.isEmpty {
                HStack {
                    Image(systemName: importManager.validateYouTubeURL(youtubeURL) ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(importManager.validateYouTubeURL(youtubeURL) ? .green : .red)
                    
                    Text(importManager.validateYouTubeURL(youtubeURL) ? "Valid YouTube URL" : "Invalid YouTube URL")
                        .font(.caption)
                        .foregroundColor(importManager.validateYouTubeURL(youtubeURL) ? .green : .red)
                    
                    Spacer()
                }
            }
            
            // Example URLs
            VStack(alignment: .leading, spacing: 8) {
                Text("Supported formats:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• youtube.com/watch?v=VIDEO_ID")
                    Text("• youtu.be/VIDEO_ID")
                    Text("• youtube.com/embed/VIDEO_ID")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
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
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(videoInfo.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                        
                        HStack {
                            Label("\(formatDuration(videoInfo.duration))", systemImage: "clock")
                            Label(videoInfo.quality, systemImage: "video")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        // Show download location
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Download to:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text(importManager.tempDirectory.path)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        }
                        .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    AsyncImage(url: URL(string: videoInfo.thumbnail)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.gray.opacity(0.3))
                    }
                    .frame(width: 80, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Download progress (if downloading)
                if importManager.isDownloading {
                    VStack(spacing: 12) {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            
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
                            .scaleEffect(y: 1.5)
                        
                        Button("Cancel Download") {
                            importManager.cancelDownload()
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.red, lineWidth: 1)
                        )
                    }
                } else {
                    // Download button
                    Button(action: downloadVideo) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title2)
                            Text("Download Video")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .scaleEffect(1.02)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: importManager.isDownloading)
                }
            }
        }
        .padding()
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
    
    // MARK: - Video Preview Section
    
    private var videoPreviewSection: some View {
        VStack(spacing: 16) {
            if let videoURL = importManager.downloadedVideoURL {
                VStack(spacing: 12) {
                    Text("Video Downloaded Successfully!")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    // Video player preview
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    Button("Select Time Range") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showingTimeSelector = true
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Time Selector Section
    
    private var timeSelectorSection: some View {
        VStack(spacing: 16) {
            Text("Select Wallpaper Duration")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Start:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatTime(importManager.selectedStartTime))
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                Slider(
                    value: $importManager.selectedStartTime,
                    in: 0...(importManager.maxDuration - 10),
                    step: 1
                ) {
                    Text("Start Time")
                } minimumValueLabel: {
                    Text("0:00")
                        .font(.caption)
                } maximumValueLabel: {
                    Text(formatTime(importManager.maxDuration - 10))
                        .font(.caption)
                }
                .onChange(of: importManager.selectedStartTime) { newValue in
                    if importManager.selectedEndTime <= newValue + 5 {
                        importManager.selectedEndTime = min(newValue + 30, importManager.maxDuration)
                    }
                }
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("End:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatTime(importManager.selectedEndTime))
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                Slider(
                    value: $importManager.selectedEndTime,
                    in: (importManager.selectedStartTime + 5)...importManager.maxDuration,
                    step: 1
                ) {
                    Text("End Time")
                } minimumValueLabel: {
                    Text(formatTime(importManager.selectedStartTime + 5))
                        .font(.caption)
                } maximumValueLabel: {
                    Text(formatTime(importManager.maxDuration))
                        .font(.caption)
                }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Duration:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatTime(importManager.selectedEndTime - importManager.selectedStartTime))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Text("Recommended: 30-60 seconds for best performance")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
        }
        .padding()
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
            }
            
            VStack(spacing: 8) {
                ProgressView(value: processingProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 1.5)
                
                HStack {
                    Text("Processing video...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(processingProgress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
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
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                if showingTimeSelector {
                    Button("Process Video") {
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
                    .disabled(isProcessing)
                }
                
                if importManager.downloadedVideoURL != nil {
                    Button("Start Over") {
                        resetImport()
                    }
                    .font(.headline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.red, lineWidth: 2)
                    )
                    .disabled(isProcessing)
                }
            }
            
            // Debug Information Panel
            debugInfoPanel
        }
    }
    
    // MARK: - Debug Info Panel
    
    private var debugInfoPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Debug Information")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Temp Directory:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(importManager.tempDirectory.path)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .textSelection(.enabled)
                
                if let videoURL = importManager.downloadedVideoURL {
                    Text("Downloaded Video:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    Text(videoURL.path)
                        .font(.caption)
                        .foregroundColor(.green)
                        .textSelection(.enabled)
                }
                
                let deps = importManager.checkDependencies()
                HStack {
                    Text("Dependencies:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("yt-dlp: \(deps.ytdlp ? "✅" : "❌")")
                        .font(.caption)
                        .foregroundColor(deps.ytdlp ? .green : .red)
                    
                    Text("ffmpeg: \(deps.ffmpeg ? "✅" : "❌")")
                        .font(.caption)
                        .foregroundColor(deps.ffmpeg ? .green : .red)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.gray.opacity(0.2), lineWidth: 1)
                )
        )
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
                        processingProgress = progress
                        processingMessage = message
                        print("📊 Download progress: \(Int(progress * 100))% - \(message)")
                    }
                }
                
                await MainActor.run {
                    print("✅ Download completed: \(videoURL.path)")
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingVideoInfo = false
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Download failed: \(error)")
                    if let ytError = error as? YouTubeError {
                        print("   YouTube Error: \(ytError.errorDescription ?? "Unknown")")
                        // Show error to user
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

// MARK: - Status Components

struct StatusStep: View {
    let icon: String
    let title: String
    let isCompleted: Bool
    let isCurrent: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(
                    isCompleted ? .green :
                    isCurrent ? .blue : .gray
                )
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(
                            isCompleted ? .green.opacity(0.2) :
                            isCurrent ? .blue.opacity(0.2) : .gray.opacity(0.1)
                        )
                )
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(
                    isCompleted ? .green :
                    isCurrent ? .blue : .gray
                )
        }
    }
}

struct StatusConnector: View {
    var body: some View {
        Rectangle()
            .fill(.gray.opacity(0.3))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    YouTubeImportView { url in
        print("Video ready: \(url)")
    }
    .frame(width: 500, height: 700)
}
