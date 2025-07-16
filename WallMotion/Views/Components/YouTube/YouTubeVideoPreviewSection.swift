import SwiftUI
import AVKit

// Updated preview section with diagnostics
struct YouTubeVideoPreviewSection: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var isPlayerReady = false
    @State private var loadingError: Error?
    @State private var diagnostics: VideoDiagnostics?
    @State private var showDiagnostics = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text("Video Downloaded Successfully!")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Button(action: {
                        showDiagnostics.toggle()
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                }
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black)
                        .frame(height: 200)
                    
                    if let error = loadingError {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundColor(.orange)
                            
                            Text("Video preview not available")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Video downloaded but format may not be compatible with preview")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            if let diagnostics = diagnostics {
                                Text("Codec: \(diagnostics.videoCodec) • Tracks: \(diagnostics.videoTrackCount)V/\(diagnostics.audioTrackCount)A")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(height: 200)
                    } else if !isPlayerReady {
                        ProgressView("Loading video...")
                            .frame(height: 200)
                    } else if let player = player {
                        VideoPlayer(player: player)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .disabled(true)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.gray.opacity(0.3), lineWidth: 1)
                )
                
                // Show diagnostics if requested
                if showDiagnostics, let diagnostics = diagnostics {
                    ScrollView {
                        Text(diagnostics.summary)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 150)
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
        .task {
            await loadPlayerWithDiagnostics()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    @MainActor
    private func loadPlayerWithDiagnostics() async {
        // First, diagnose the video
        let importManager = YouTubeImportManager()
        let videoDiagnostics = await importManager.diagnoseVideoFile(videoURL)
        self.diagnostics = videoDiagnostics
        
        print("📊 Video Diagnostics:")
        print(videoDiagnostics.summary)
        
        // If not playable, don't try to create player
        if !videoDiagnostics.isPlayable {
            self.loadingError = VideoError.notPlayable
            return
        }
        
        // If no video tracks, can't play
        if videoDiagnostics.videoTrackCount == 0 {
            self.loadingError = VideoError.noVideoTrack
            return
        }
        
        do {
            let asset = AVAsset(url: videoURL)
            
            // Try to create player item
            let playerItem = AVPlayerItem(asset: asset)
            
            await withCheckedContinuation { continuation in
                let observer = playerItem.observe(\.status) { item, _ in
                    switch item.status {
                    case .readyToPlay:
                        Task { @MainActor in
                            let newPlayer = AVPlayer(playerItem: playerItem)
                            newPlayer.isMuted = true
                            newPlayer.actionAtItemEnd = .none
                            
                            self.player = newPlayer
                            self.isPlayerReady = true
                            
                            newPlayer.seek(to: .zero)
                            newPlayer.pause()
                        }
                        continuation.resume()
                        
                    case .failed:
                        Task { @MainActor in
                            self.loadingError = item.error ?? VideoError.loadFailed
                            print("❌ AVPlayerItem failed: \(item.error?.localizedDescription ?? "Unknown error")")
                        }
                        continuation.resume()
                        
                    case .unknown:
                        break
                        
                    @unknown default:
                        break
                    }
                }
                
                Task {
                    try? await Task.sleep(for: .seconds(10))
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
        isPlayerReady = false
        loadingError = nil
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
