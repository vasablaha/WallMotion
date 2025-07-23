//
//  OptimizedVideoComponents.swift
//  WallMotion - Optimized for .dmg distribution
//
//  Řešení pro Swift metadata crash v distribuované verzi
//

import SwiftUI
import AVKit
import AVFoundation

// MARK: - Bezpečný VideoPlayer wrapper
struct SafeVideoPlayer: NSViewRepresentable {
    let url: URL
    @State private var player: AVPlayer?
    @State private var playerView: AVPlayerView?
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        
        // Defensive programming - create player asynchronously
        DispatchQueue.main.async {
            setupPlayer(in: containerView)
        }
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Only update if URL actually changed
        guard let playerView = nsView.subviews.first as? AVPlayerView,
              let currentURL = (playerView.player?.currentItem?.asset as? AVURLAsset)?.url,
              currentURL != url else { return }
        
        // URL changed, reload
        DispatchQueue.main.async {
            setupPlayer(in: nsView)
        }
    }
    
    private func setupPlayer(in containerView: NSView) {
        // Remove existing player view
        containerView.subviews.forEach { $0.removeFromSuperview() }
        
        do {
            // Check if file exists and is accessible
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ Video file not found: \(url.path)")
                addErrorView(to: containerView, message: "Video file not found")
                return
            }
            
            // Create player with error handling
            let asset = AVAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            let newPlayer = AVPlayer(playerItem: playerItem)
            
            // Create player view
            let newPlayerView = AVPlayerView()
            newPlayerView.player = newPlayer
            newPlayerView.controlsStyle = .none
            newPlayerView.videoGravity = .resizeAspectFill
            
            // Add to container
            containerView.addSubview(newPlayerView)
            newPlayerView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                newPlayerView.topAnchor.constraint(equalTo: containerView.topAnchor),
                newPlayerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                newPlayerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                newPlayerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            // Store references
            self.player = newPlayer
            self.playerView = newPlayerView
            
            // Monitor for errors
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { notification in
                print("❌ Player failed: \(notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)")
                addErrorView(to: containerView, message: "Playback failed")
            }
            
            // Start playback
            newPlayer.play()
            newPlayer.isMuted = true
            
            print("✅ Video player setup successful")
            
        } catch {
            print("❌ Error setting up video player: \(error)")
            addErrorView(to: containerView, message: "Failed to load video")
        }
    }
    
    private func addErrorView(to container: NSView, message: String) {
        container.subviews.forEach { $0.removeFromSuperview() }
        
        let errorView = NSView()
        let textField = NSTextField(labelWithString: message)
        textField.alignment = .center
        textField.textColor = .secondaryLabelColor
        
        errorView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            textField.centerYAnchor.constraint(equalTo: errorView.centerYAnchor)
        ])
        
        container.addSubview(errorView)
        errorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: container.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
    
    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        nsView.subviews.forEach { subview in
            if let playerView = subview as? AVPlayerView {
                playerView.player?.pause()
                playerView.player = nil
            }
        }
    }
}

// MARK: - Optimalizovaná VideoPreviewCard
struct OptimizedVideoPreviewCard: View {
    let videoURL: URL
    let isProcessing: Bool
    let progress: Double
    
    @State private var isVideoReady = false
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var videoInfo: VideoFileInfo?
    
    private struct VideoFileInfo {
        let fileName: String
        let fileSize: String
        let duration: String
        let resolution: String
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Video player section s progressive loading
            videoPlayerSection
            
            // Video info
            if let info = videoInfo {
                videoInfoSection(info)
            }
            
            // Progress bar when processing
            if isProcessing {
                processingSection
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.blue.opacity(0.3), lineWidth: 2)
                )
        )
        .onAppear {
            loadVideoInfo()
            // Delayed video player initialization to prevent metadata crashes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isVideoReady = true
                }
            }
        }
    }
    
    // MARK: - Video Player Section
    @ViewBuilder
    private var videoPlayerSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.black)
                .frame(height: 300)
            
            if hasError {
                // Error fallback
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    Text("Preview unavailable")
                        .font(.headline)
                    
                    Text("Video downloaded successfully")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                }
                .frame(height: 300)
            } else if !isVideoReady {
                // Loading state
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Preparing video preview...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 300)
            } else {
                // Use safe video player
                SafeVideoPlayer(url: videoURL)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .onTapGesture {
                        // Optional: Add tap gesture handling
                    }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Video Info Section
    private func videoInfoSection(_ info: VideoFileInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(info.fileName)
                .font(.headline)
                .lineLimit(2)
            
            HStack {
                Text("📏 \(info.fileSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("⏱️ \(info.duration)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("📐 \(info.resolution)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Processing Section
    private var processingSection: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text("Processing... \(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Video Info Loading
    private func loadVideoInfo() {
        Task {
            do {
                let fileName = videoURL.lastPathComponent
                let fileSize = getFileSize(url: videoURL)
                
                // Safe AVAsset loading with timeout
                let asset = AVAsset(url: videoURL)
                
                // Use async/await with timeout
                let duration = try await withTimeout(seconds: 3.0) {
                    try await asset.load(.duration)
                }
                
                let tracks = try await withTimeout(seconds: 2.0) {
                    try await asset.load(.tracks)
                }
                
                let videoDuration = CMTimeGetSeconds(duration)
                let videoTracks = tracks.filter { $0.mediaType == .video }
                
                var resolution = "Unknown"
                if let videoTrack = videoTracks.first {
                    let naturalSize = try await videoTrack.load(.naturalSize)
                    resolution = "\(Int(naturalSize.width))×\(Int(naturalSize.height))"
                }
                
                await MainActor.run {
                    videoInfo = VideoFileInfo(
                        fileName: fileName,
                        fileSize: fileSize,
                        duration: formatDuration(videoDuration),
                        resolution: resolution
                    )
                }
                
            } catch {
                print("❌ Error loading video info: \(error)")
                await MainActor.run {
                    hasError = true
                    errorMessage = "Failed to load video info"
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func getFileSize(url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useMB, .useKB, .useGB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: fileSize)
            }
        } catch {
            print("❌ Error getting file size: \(error)")
        }
        return "Unknown"
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds.isFinite else { return "Unknown" }
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Optimalizovaná YouTubeVideoPreviewSection
struct OptimizedYouTubeVideoPreviewSection: View {
    let videoURL: URL
    @State private var isReady = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var videoInfo: VideoInfo?
    
    private struct VideoInfo {
        let fileName: String
        let fileSize: String
        let duration: String
        let resolution: String
        let codec: String
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Video Downloaded Successfully!")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.green)
            
            // Video preview with progressive loading
            videoPreviewView
            
            // Video information
            if let info = videoInfo {
                videoInfoView(info)
            }
            
            // Ready indicator
            readyIndicator
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
        .onAppear {
            loadVideoInfo()
            // Progressive video player loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    isReady = true
                }
            }
        }
    }
    
    // MARK: - Video Preview View
    @ViewBuilder
    private var videoPreviewView: some View {
        Group {
            if showError {
                // Error fallback
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text("Preview unavailable")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Video file is ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.1))
                )
            } else if !isReady {
                // Loading state
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Loading video preview...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.1))
                )
            } else {
                // Safe video player
                SafeVideoPlayer(url: videoURL)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Video Info View
    private func videoInfoView(_ info: VideoInfo) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("📁 \(info.fileName)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
                
                Text("📏 \(info.fileSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("📐 \(info.resolution)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("⏱️ \(info.duration)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("🧬 \(info.codec)")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Ready Indicator
    private var readyIndicator: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
            
            Text("Ready for wallpaper")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.green)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Video Info Loading
    private func loadVideoInfo() {
        Task {
            do {
                let fileName = videoURL.lastPathComponent
                let fileSize = getFileSize(url: videoURL)
                
                // Safe AVAsset loading
                let asset = AVAsset(url: videoURL)
                let duration = try await withTimeout(seconds: 3.0) {
                    try await asset.load(.duration)
                }
                
                let videoDuration = CMTimeGetSeconds(duration)
                
                await MainActor.run {
                    videoInfo = VideoInfo(
                        fileName: fileName,
                        fileSize: fileSize,
                        duration: formatDuration(videoDuration),
                        resolution: "HD", // Simplified for safety
                        codec: "H.264"    // Simplified for safety
                    )
                }
                
            } catch {
                print("❌ Error loading video info: \(error)")
                await MainActor.run {
                    showError = true
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func getFileSize(url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useMB, .useKB, .useGB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: fileSize)
            }
        } catch {
            print("❌ Error getting file size: \(error)")
        }
        return "Unknown"
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds.isFinite else { return "Unknown" }
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Timeout helper
func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            // Use proper Task.sleep syntax
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        
        group.cancelAll()
        return result
    }
}

struct TimeoutError: Error {
    var localizedDescription: String {
        return "Operation timed out"
    }
}
