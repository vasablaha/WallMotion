//
//  YouTubeVideoInfoSection.swift
//  WallMotion
//
//  Video info section with navigation-style buttons
//

import SwiftUI

struct YouTubeVideoInfoSection: View {
    let importManager: YouTubeImportManager
    let onDownloadVideo: () -> Void
    let onCancelDownload: () -> Void
    
    var body: some View {
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
                
                if importManager.isDownloading {
                    YouTubeDownloadProgress(
                        progress: importManager.downloadProgress,
                        onCancel: onCancelDownload
                    )
                } else {
                    YouTubeDownloadButton(onDownload: onDownloadVideo)
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
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct YouTubeDownloadProgress: View {
    let progress: Double
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text("Downloading...")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 1.5)
            
            Button(action: onCancel) {
                HStack {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.red)
                    
                    Text("Cancel Download")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct YouTubeDownloadButton: View {
    let onDownload: () -> Void
    
    var body: some View {
        Button(action: onDownload) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Download Video")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Download to temp directory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.blue.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    YouTubeVideoInfoSection(
        importManager: YouTubeImportManager(),
        onDownloadVideo: {},
        onCancelDownload: {}
    )
    .padding()
}
