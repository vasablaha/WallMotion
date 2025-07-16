//
//  YouTubeDebugInfoSection.swift
//  WallMotion
//
//  Debug info section and supporting components for YouTube Import
//

import SwiftUI

struct YouTubeDebugInfoSection: View {
    let importManager: YouTubeImportManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Debug Information")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Development and troubleshooting details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                YouTubeDebugInfoRow(
                    icon: "folder",
                    title: "Temp Directory",
                    value: importManager.tempDirectory.path,
                    color: .blue
                )
                
                if let videoURL = importManager.downloadedVideoURL {
                    YouTubeDebugInfoRow(
                        icon: "video",
                        title: "Downloaded Video",
                        value: videoURL.path,
                        color: .green
                    )
                }
                
                YouTubeDependencyStatus(importManager: importManager)
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
}

struct YouTubeDebugInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            
            Spacer()
        }
    }
}

struct YouTubeDependencyStatus: View {
    let importManager: YouTubeImportManager
    
    var body: some View {
        HStack {
            Image(systemName: "gearshape.2")
                .foregroundColor(.purple)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Dependencies")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                let deps = importManager.checkDependencies()
                HStack(spacing: 16) {
                    YouTubeDependencyBadge(name: "yt-dlp", isInstalled: deps.ytdlp)
                    YouTubeDependencyBadge(name: "ffmpeg", isInstalled: deps.ffmpeg)
                }
            }
            
            Spacer()
        }
    }
}

struct YouTubeDependencyBadge: View {
    let name: String
    let isInstalled: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isInstalled ? Color.green : Color.red)
                .font(.caption)
            
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isInstalled ? Color.green : Color.red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((isInstalled ? Color.green : Color.red).opacity(0.1))
        )
    }
}

#Preview {
    YouTubeDebugInfoSection(
        importManager: YouTubeImportManager()
    )
    .padding()
}
