//
//  YouTubeVideoPreviewSection.swift
//  WallMotion
//
//  CRASH-SAFE VERSION - No risky VideoPlayer component
//

import SwiftUI
import AVKit
import AVFoundation

struct YouTubeVideoPreviewSection: View {
    let videoURL: URL
    @State private var videoInfo: VideoInfo?
    @State private var isLoadingInfo = true
    
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
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Video Downloaded Successfully!")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Text("Ready to set as wallpaper")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // SAFE Static preview - no risky VideoPlayer
            safeStaticPreview
            
            // Video information
            if isLoadingInfo {
                ProgressView("Loading video info...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let info = videoInfo {
                videoInfoView(info)
            }
            
            // Action buttons
            actionButtonsView
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
            loadVideoInfoSafely()
        }
    }
    
    // MARK: - Safe Static Preview (No VideoPlayer)
    
    private var safeStaticPreview: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(LinearGradient(
                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(height: 160)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "video.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Video Ready")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("No preview to prevent crashes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Quick action buttons
                    HStack(spacing: 12) {
                        Button("Preview in QuickTime") {
                            openInQuickTime()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Show in Finder") {
                            revealInFinder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Video Info View
    
    private func videoInfoView(_ info: VideoInfo) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Video Information")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: 16)
            ], spacing: 8) {
                InfoRow(label: "File", value: info.fileName)
                InfoRow(label: "Size", value: info.fileSize)
                InfoRow(label: "Duration", value: info.duration)
                InfoRow(label: "Resolution", value: info.resolution)
                InfoRow(label: "Codec", value: info.codec)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
    
    private struct InfoRow: View {
        let label: String
        let value: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            Button("Show in Finder") {
                revealInFinder()
            }
            .buttonStyle(.bordered)
            
            Button("Open in QuickTime") {
                openInQuickTime()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Safe Video Info Loading
    
    private func loadVideoInfoSafely() {
        print("📊 Loading video info safely for: \(videoURL.lastPathComponent)")
        
        Task {
            do {
                // This is safe - no UI components, just data
                let asset = AVURLAsset(url: videoURL)
                
                let fileName = videoURL.lastPathComponent
                let fileSize = getFileSize(url: videoURL) ?? "Unknown"
                
                async let durationTask = loadDuration(asset: asset)
                async let tracksTask = asset.loadTracks(withMediaType: .video)
                
                let duration = await durationTask
                let videoTracks = await tracksTask
                
                var resolution = "Unknown"
                var codec = "Unknown"
                
                if let firstTrack = videoTracks.first {
                    let naturalSize = await loadNaturalSize(track: firstTrack)
                    resolution = "\(Int(naturalSize.width))×\(Int(naturalSize.height))"
                    
                    if let formatDescriptions = firstTrack.formatDescriptions as? [CMFormatDescription],
                       let formatDescription = formatDescriptions.first {
                        let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                        codec = fourCCToString(codecType)
                    }
                }
                
                let info = VideoInfo(
                    fileName: fileName,
                    fileSize: fileSize,
                    duration: duration,
                    resolution: resolution,
                    codec: codec
                )
                
                await MainActor.run {
                    self.videoInfo = info
                    self.isLoadingInfo = false
                    print("✅ Video info loaded safely")
                }
                
            } catch {
                print("❌ Error loading video info: \(error)")
                await MainActor.run {
                    self.isLoadingInfo = false
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func openInQuickTime() {
        NSWorkspace.shared.open(videoURL)
    }
    
    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([videoURL])
    }
    
    private func getFileSize(url: URL) -> String? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            }
        } catch {
            print("Error getting file size: \(error)")
        }
        return nil
    }
    
    // MARK: - Safe async helpers
    
    private func loadDuration(asset: AVURLAsset) async -> String {
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            
            if seconds.isFinite && seconds > 0 {
                let minutes = Int(seconds) / 60
                let remainingSeconds = Int(seconds) % 60
                return String(format: "%d:%02d", minutes, remainingSeconds)
            } else {
                return "Unknown"
            }
        } catch {
            print("Error loading duration: \(error)")
            return "Unknown"
        }
    }
    
    private func loadNaturalSize(track: AVAssetTrack) async -> CGSize {
        do {
            return try await track.load(.naturalSize)
        } catch {
            print("Error loading natural size: \(error)")
            return CGSize.zero
        }
    }
    
    private func fourCCToString(_ fourCC: FourCharCode) -> String {
        let bytes = [
            UInt8((fourCC >> 24) & 0xFF),
            UInt8((fourCC >> 16) & 0xFF),
            UInt8((fourCC >> 8) & 0xFF),
            UInt8(fourCC & 0xFF)
        ]
        
        if let string = String(bytes: bytes, encoding: .ascii) {
            return string
        } else {
            return "Unknown"
        }
    }
}
