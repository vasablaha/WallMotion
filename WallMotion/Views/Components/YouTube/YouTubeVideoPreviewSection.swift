//
//  YouTubeVideoPreviewSection.swift
//  WallMotion
//
//  Clean and simple video preview section for YouTube Import
//

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
            
            // Video preview
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
            setupVideoPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    // MARK: - Video Preview View
    
    @ViewBuilder
    private var videoPreviewView: some View {
        Group {
            if let player = player, isReady {
                // Working video player
                VideoPlayer(player: player)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onAppear {
                        player.volume = 0.0
                        player.play()
                        setupLooping()
                    }
            } else if showError {
                // Error fallback
                errorFallbackView
            } else {
                // Loading state
                loadingView
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var errorFallbackView: some View {
        RoundedRectangle(cornerRadius: 12)
            .frame(height: 200)
            .foregroundColor(.gray.opacity(0.1))
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "video.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    Text("Video Ready for Wallpaper")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Preview temporarily unavailable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            )
    }
    
    private var loadingView: some View {
        RoundedRectangle(cornerRadius: 12)
            .frame(height: 200)
            .foregroundColor(.gray.opacity(0.05))
            .overlay(
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Loading video preview...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            )
    }
    
    // MARK: - Video Info View
    
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
                    .foregroundColor(getQualityColor(info.resolution))
                
                Spacer()
                
                Text("⏱️ \(info.duration)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("🧬 \(info.codec)")
                    .font(.caption)
                    .foregroundColor(isCodecCompatible(info.codec) ? .green : .orange)
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
    
    // MARK: - Video Setup and Cleanup
    
    private func setupVideoPlayer() {
        print("🎬 Setting up video player for: \(videoURL.lastPathComponent)")
        
        let playerItem = AVPlayerItem(url: videoURL)
        player = AVPlayer(playerItem: playerItem)
        
        // Simple status monitoring
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            checkPlayerStatus()
        }
    }
    
    private func checkPlayerStatus() {
        guard let item = player?.currentItem else {
            showError = true
            errorMessage = "No player item"
            return
        }
        
        switch item.status {
        case .readyToPlay:
            print("✅ Player ready to play")
            isReady = true
        case .failed:
            print("❌ Player failed: \(item.error?.localizedDescription ?? "Unknown error")")
            showError = true
            errorMessage = item.error?.localizedDescription ?? "Unknown error"
        case .unknown:
            print("⏳ Player status unknown, waiting...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if item.status == .readyToPlay {
                    self.isReady = true
                } else {
                    self.showError = true
                    self.errorMessage = "Player loading timeout"
                }
            }
        @unknown default:
            showError = true
            errorMessage = "Unknown player status"
        }
    }
    
    private func setupLooping() {
        guard let player = player else { return }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        print("▶️ Started video preview with looping")
    }
    
    private func cleanupPlayer() {
        player?.pause()
        player = nil
        isReady = false
        showError = false
        NotificationCenter.default.removeObserver(self)
        print("🧹 Cleaned up video player")
    }
    
    // MARK: - Video Information Loading
    
    private func loadVideoInfo() {
        Task {
            do {
                let asset = AVAsset(url: videoURL)
                
                // Load basic properties
                let duration = try await asset.load(.duration)
                let tracks = try await asset.load(.tracks)
                
                let videoDuration = CMTimeGetSeconds(duration)
                let videoTracks = tracks.filter { $0.mediaType == .video }
                
                var resolution = CGSize.zero
                var codec = "Unknown"
                
                // Get video track info
                if let videoTrack = videoTracks.first {
                    let naturalSize = try await videoTrack.load(.naturalSize)
                    resolution = naturalSize
                    
                    // Get codec
                    let formatDescriptions = videoTrack.formatDescriptions
                    for description in formatDescriptions {
                        let formatDescription = description as! CMVideoFormatDescription
                        let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                        codec = fourCharCodeToString(codecType)
                        break
                    }
                }
                
                // Get file info
                let fileName = videoURL.lastPathComponent
                let fileSize = getFileSize()
                let durationStr = formatDuration(videoDuration)
                let resolutionStr = formatResolution(resolution)
                
                await MainActor.run {
                    self.videoInfo = VideoInfo(
                        fileName: fileName,
                        fileSize: fileSize,
                        duration: durationStr,
                        resolution: resolutionStr,
                        codec: codec
                    )
                }
                
                print("✅ Video info loaded: \(resolutionStr), \(codec), \(durationStr)")
                
            } catch {
                print("❌ Failed to load video info: \(error)")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getFileSize() -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
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
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func formatResolution(_ size: CGSize) -> String {
        let width = Int(size.width)
        let height = Int(size.height)
        
        if height >= 2160 {
            return "4K (\(width)×\(height))"
        } else if height >= 1440 {
            return "2K (\(width)×\(height))"
        } else if height >= 1080 {
            return "HD (\(width)×\(height))"
        } else if height >= 720 {
            return "HD Ready (\(width)×\(height))"
        } else {
            return "SD (\(width)×\(height))"
        }
    }
    
    private func getQualityColor(_ resolution: String) -> Color {
        if resolution.contains("4K") {
            return .purple
        } else if resolution.contains("2K") {
            return .blue
        } else if resolution.contains("HD") {
            return .green
        } else {
            return .orange
        }
    }
    
    private func isCodecCompatible(_ codec: String) -> Bool {
        let compatibleCodecs = ["avc1", "h264", "mp4v", "hvc1", "hev1"]
        return compatibleCodecs.contains { compatibleCodec in
            codec.lowercased().contains(compatibleCodec.lowercased())
        }
    }
    
    private func fourCharCodeToString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "Unknown"
    }
}


// Update VideoPreviewCard with same safe approach
struct VideoPreviewCard: View {
    let videoURL: URL
    let isProcessing: Bool
    let progress: Double
    
    @State private var player: AVPlayer?
    @State private var isPlayerReady = false
    @State private var loadingError: Error?
    @State private var playerItem: AVPlayerItem?
    
    var body: some View {
        VStack(spacing: 16) {
            // Video player section
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black)
                    .frame(height: 300)
                
                if let error = loadingError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.orange)
                        
                        Text("Preview unavailable")
                            .font(.headline)
                        
                        Text("Video downloaded successfully")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 300)
                } else if !isPlayerReady {
                    ProgressView("Loading video preview...")
                        .frame(height: 300)
                } else if let player = player {
                    VideoPlayer(player: player)
                        .frame(height: 300)
                        .cornerRadius(16)
                        .onTapGesture {
                            // Toggle play/pause on tap
                            if player.timeControlStatus == .playing {
                                player.pause()
                            } else {
                                player.play()
                            }
                        }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.primary.opacity(0.2), lineWidth: 1)
            )
            
            // Video info
            VStack(alignment: .leading, spacing: 8) {
                Text(videoURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(2)
                
                if let fileSize = getFileSize(url: videoURL) {
                    Text("Size: \(fileSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Progress bar (when processing)
            if isProcessing {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text("Processing... \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
        .task {
            await loadPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    @MainActor
    private func loadPlayer() async {
        do {
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                throw VideoError.fileNotFound
            }
            
            let asset = AVAsset(url: videoURL)
            
            // Wait for file to be ready
            try await Task.sleep(for: .milliseconds(800))
            
            let isPlayable = try await asset.load(.isPlayable)
            guard isPlayable else {
                throw VideoError.notPlayable
            }
            
            let newPlayerItem = AVPlayerItem(asset: asset)
            self.playerItem = newPlayerItem
            
            await withCheckedContinuation { continuation in
                let observer = newPlayerItem.observe(\.status) { item, _ in
                    switch item.status {
                    case .readyToPlay:
                        Task { @MainActor in
                            let newPlayer = AVPlayer(playerItem: newPlayerItem)
                            newPlayer.isMuted = false // Allow sound for main preview
                            newPlayer.actionAtItemEnd = .pause
                            
                            self.player = newPlayer
                            self.isPlayerReady = true
                            
                            newPlayer.seek(to: .zero)
                            newPlayer.pause()
                        }
                        continuation.resume()
                        
                    case .failed:
                        Task { @MainActor in
                            self.loadingError = item.error ?? VideoError.loadFailed
                        }
                        continuation.resume()
                        
                    case .unknown:
                        break
                        
                    @unknown default:
                        break
                    }
                }
                
                Task {
                    try? await Task.sleep(for: .seconds(15))
                    observer.invalidate()
                    if !self.isPlayerReady && self.loadingError == nil {
                        await MainActor.run {
                            self.loadingError = VideoError.timeout
                        }
                        continuation.resume()
                    }
                }
            }
            
        } catch {
            self.loadingError = error
            print("❌ Video player loading failed: \(error)")
        }
    }
    
    private func cleanupPlayer() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
        isPlayerReady = false
        loadingError = nil
    }
    
    private func getFileSize(url: URL) -> String? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                return formatter.string(fromByteCount: fileSize)
            }
        } catch {
            print("Failed to get file size: \(error)")
        }
        return nil
    }
}


enum VideoError: LocalizedError {
    case fileNotFound
    case notPlayable
    case loadFailed
    case timeout
    case noVideoTrack
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Video file not found"
        case .notPlayable:
            return "Video format not supported by player"
        case .loadFailed:
            return "Failed to load video"
        case .timeout:
            return "Loading timeout"
        case .noVideoTrack:
            return "No video track found in file"
        }
    }
}
