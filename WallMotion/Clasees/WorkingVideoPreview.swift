//
//  WorkingVideoPreview.swift
//  WallMotion
//
//  Created by Šimon Filípek on 16.07.2025.
//


// Jednoduchý a funkční video preview - nahraď YouTubeVideoPreviewSection

import SwiftUI
import AVKit
import AVFoundation

struct WorkingVideoPreview: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var isReady = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Text("Video Downloaded Successfully!")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                // Simple video preview
                Group {
                    if let player = player, isReady {
                        // Working video player
                        VideoPlayer(player: player)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                            )
                            .onAppear {
                                setupAutoPlay()
                            }
                    } else if showError {
                        // Error fallback with file info
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
                                    
                                    Text(errorMessage)
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        // Loading state
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
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                
                // Video file information
                VStack(spacing: 8) {
                    HStack {
                        Text("📁 File:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(videoURL.lastPathComponent)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("📏 Size:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(getFileSize())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("▶️ Ready for wallpaper")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal)
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
        .onAppear {
            setupVideoPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    private func setupVideoPlayer() {
        print("🎬 Setting up video player for: \(videoURL.lastPathComponent)")
        
        // Create player with simple setup
        let playerItem = AVPlayerItem(url: videoURL)
        player = AVPlayer(playerItem: playerItem)
        
        // Add observers for status
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            // Loop the video
            self.player?.seek(to: .zero)
            self.player?.play()
        }
        
        // Monitor player readiness
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let item = self.player?.currentItem {
                switch item.status {
                case .readyToPlay:
                    print("✅ Player ready to play")
                    self.isReady = true
                case .failed:
                    print("❌ Player failed: \(item.error?.localizedDescription ?? "Unknown error")")
                    self.showError = true
                    self.errorMessage = item.error?.localizedDescription ?? "Unknown error"
                case .unknown:
                    print("⏳ Player status unknown, waiting...")
                    // Give it more time
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if item.status == .readyToPlay {
                            self.isReady = true
                        } else {
                            print("⚠️ Player timeout, showing fallback")
                            self.showError = true
                            self.errorMessage = "Player loading timeout"
                        }
                    }
                @unknown default:
                    print("❓ Unknown player status")
                    self.showError = true
                    self.errorMessage = "Unknown player status"
                }
            }
        }
    }
    
    private func setupAutoPlay() {
        guard let player = player else { return }
        
        // Mute and play
        player.volume = 0.0
        player.play()
        
        print("▶️ Started video preview playback")
    }
    
    private func cleanupPlayer() {
        player?.pause()
        player = nil
        NotificationCenter.default.removeObserver(self)
        print("🧹 Cleaned up video player")
    }
    
    private func getFileSize() -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                return formatFileSize(fileSize)
            }
        } catch {
            print("❌ Error getting file size: \(error)")
        }
        return "Unknown"
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
