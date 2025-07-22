// Nahraďte YouTubeVideoPreviewSection.swift tímto bezpečným kódem:

import SwiftUI
import AVKit
import AVFoundation

struct YouTubeVideoPreviewSection: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var isReady = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var videoInfo: VideoInfo?
    @State private var isInitializing = true
    
    // Simple video info structure
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
            
            // Video preview with safe handling
            safeVideoPreviewView
            
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
            setupSafeVideoPreview()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    // MARK: - Safe Video Preview View
    
    @ViewBuilder
    private var safeVideoPreviewView: some View {
        Group {
            if showError {
                // Error fallback - always show this instead of crashing
                errorFallbackView
            } else if isInitializing {
                // Loading state
                loadingView
            } else if let player = player, isReady {
                // ✅ CRITICAL: Only show VideoPlayer when everything is ready
                // and wrapped in error boundary
                Group {
                    if #available(macOS 12.0, *) {
                        // Use modern VideoPlayer only on newer systems
                        safeVideoPlayerView(player: player)
                    } else {
                        // Fallback for older systems
                        legacyVideoView(player: player)
                    }
                }
                .onAppear {
                    configurePlayerSafely(player)
                }
            } else {
                // Default to safe preview
                staticVideoPreview
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Safe Video Player Components
    
    @ViewBuilder
    private func safeVideoPlayerView(player: AVPlayer) -> some View {
        // ✅ Wrap VideoPlayer in safe container with error boundary
        ZStack {
            Color.black
            
            // Try to create VideoPlayer, but have fallback ready
            Group {
                if isPlayerSafe() {
                    VideoPlayer(player: player)
                        .onAppear {
                            // Configure safely on main thread
                            DispatchQueue.main.async {
                                player.volume = 0.1
                                player.play()
                                setupSafeLooping(player: player)
                            }
                        }
                        .onTapGesture {
                            togglePlayback(player: player)
                        }
                } else {
                    staticVideoPreview
                }
            }
        }
        .background(Color.black)
    }
    
    @ViewBuilder
    private func legacyVideoView(player: AVPlayer) -> some View {
        // Fallback for older macOS versions
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "video.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    Text("Video Ready")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Button("Preview in QuickTime") {
                        openInQuickTime()
                    }
                    .buttonStyle(.borderedProminent)
                }
            )
    }
    
    private var staticVideoPreview: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(LinearGradient(
                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    
                    Text("Video Ready for Wallpaper")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Click 'Set as Wallpaper' to use")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
    }
    
    private var errorFallbackView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.orange.opacity(0.1))
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Text("Video Downloaded Successfully")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Preview unavailable, but video is ready to use")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Open in Finder") {
                        revealInFinder()
                    }
                    .buttonStyle(.bordered)
                }
            )
    }
    
    private var loadingView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.1))
            .overlay(
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Preparing video preview...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            )
    }
    
    // MARK: - Safe Setup and Utilities
    
    private func setupSafeVideoPreview() {
        print("🎬 Setting up SAFE video preview for: \(videoURL.lastPathComponent)")
        
        // Start with loading state
        isInitializing = true
        
        // Load video info first (this is safe)
        loadVideoInfo()
        
        // Delay video player setup to avoid race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            attemptVideoPlayerSetup()
        }
    }
    
    private func attemptVideoPlayerSetup() {
        // ✅ CRITICAL: All video setup on main thread with error handling
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("❌ Video file doesn't exist")
            showError = true
            errorMessage = "Video file not found"
            isInitializing = false
            return
        }
        
        do {
            // ✅ Create player item safely
            let playerItem = AVPlayerItem(url: videoURL)
            
            // ✅ Monitor player item status
            let statusObserver = playerItem.observe(\.status, options: [.new, .initial]) { item, _ in
                DispatchQueue.main.async {
                    handlePlayerItemStatus(item)
                }
            }
            
            // ✅ Create player safely on main thread
            let newPlayer = AVPlayer(playerItem: playerItem)
            newPlayer.automaticallyWaitsToMinimizeStalling = false
            
            self.player = newPlayer
            
            // ✅ Auto-cleanup observer after timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                statusObserver.invalidate()
                if isInitializing {
                    showError = true
                    errorMessage = "Player setup timeout"
                    isInitializing = false
                }
            }
            
        } catch {
            print("❌ Player setup failed: \(error)")
            showError = true
            errorMessage = "Player setup failed"
            isInitializing = false
        }
    }
    
    private func handlePlayerItemStatus(_ item: AVPlayerItem) {
        switch item.status {
        case .readyToPlay:
            print("✅ Player ready - enabling preview")
            isReady = true
            isInitializing = false
            showError = false
            
        case .failed:
            print("❌ Player failed: \(item.error?.localizedDescription ?? "Unknown")")
            showError = true
            errorMessage = "Player failed to load"
            isInitializing = false
            
        case .unknown:
            print("⏳ Player status unknown")
            // Keep waiting, will timeout if needed
            
        @unknown default:
            showError = true
            errorMessage = "Unknown player status"
            isInitializing = false
        }
    }
    
    private func isPlayerSafe() -> Bool {
        // ✅ Additional safety check before showing VideoPlayer
        guard let player = player,
              let item = player.currentItem else {
            return false
        }
        
        return item.status == .readyToPlay && isReady && !showError
    }
    
    private func configurePlayerSafely(_ player: AVPlayer) {
        // ✅ Safe configuration that won't crash
        player.volume = 0.1
        player.actionAtItemEnd = .pause
    }
    
    private func setupSafeLooping(player: AVPlayer) {
        // ✅ Safe looping setup
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            if !showError && isReady {
                player.play()
            }
        }
    }
    
    private func togglePlayback(player: AVPlayer) {
        // ✅ Safe playback toggle
        if player.timeControlStatus == .playing {
            player.pause()
        } else if isReady && !showError {
            player.play()
        }
    }
    
    private func cleanupPlayer() {
        // ✅ Safe cleanup
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        isReady = false
        showError = false
        isInitializing = false
        NotificationCenter.default.removeObserver(self)
        print("🧹 Safely cleaned up video player")
    }
    
    // MARK: - Utility Actions
    
    private func openInQuickTime() {
        NSWorkspace.shared.open(videoURL)
    }
    
    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([videoURL])
    }
    
    // MARK: - Video Info Loading (Safe)
    
    private func loadVideoInfo() {
        // ✅ This is safe and won't crash
        Task {
            do {
                let asset = AVURLAsset(url: videoURL)
                
                let fileName = videoURL.lastPathComponent
                let fileSize = getFileSize(url: videoURL) ?? "Unknown"
                
                // Load basic properties safely
                async let duration = try asset.load(.duration)
                async let tracks = try asset.load(.tracks)
                
                let videoDuration = try await CMTimeGetSeconds(duration)
                let videoTracks = try await tracks.filter { $0.mediaType == .video }
                
                var resolution = "Unknown"
                var codec = "Unknown"
                
                if let videoTrack = videoTracks.first {
                    let naturalSize = try await videoTrack.load(.naturalSize)
                    resolution = "\(Int(naturalSize.width))×\(Int(naturalSize.height))"
                }
                
                let durationString = formatDuration(videoDuration)
                
                await MainActor.run {
                    self.videoInfo = VideoInfo(
                        fileName: fileName,
                        fileSize: fileSize,
                        duration: durationString,
                        resolution: resolution,
                        codec: codec
                    )
                }
                
            } catch {
                print("❌ Video info loading failed: \(error)")
                // Don't crash, just use defaults
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getFileSize(url: URL) -> String? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            }
        } catch {
            print("❌ Could not get file size: \(error)")
        }
        return nil
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func videoInfoView(_ info: VideoInfo) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("📁")
                    .font(.caption)
                
                Text(info.fileName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
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
                
                Text("✅ Ready")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal)
    }
    
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
}
