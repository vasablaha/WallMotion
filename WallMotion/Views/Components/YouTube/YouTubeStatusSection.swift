//
//  YouTubeStatusSection.swift
//  WallMotion
//
//  Status section and supporting components for YouTube Import
//

import SwiftUI

struct YouTubeStatusSection: View {
    let youtubeURL: String
    let importManager: YouTubeImportManager
    let showingTimeSelector: Bool
    let isProcessing: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Current Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 16) {
                YouTubeStatusStep(
                    icon: "link",
                    title: "URL",
                    isCompleted: !youtubeURL.isEmpty && importManager.validateYouTubeURL(youtubeURL),
                    isCurrent: youtubeURL.isEmpty || !importManager.validateYouTubeURL(youtubeURL)
                )
                
                YouTubeStatusConnector()
                
                YouTubeStatusStep(
                    icon: "info.circle",
                    title: "Info",
                    isCompleted: importManager.videoInfo != nil,
                    isCurrent: !youtubeURL.isEmpty && importManager.validateYouTubeURL(youtubeURL) && importManager.videoInfo == nil
                )
                
                YouTubeStatusConnector()
                
                YouTubeStatusStep(
                    icon: "arrow.down.circle",
                    title: "Download",
                    isCompleted: importManager.downloadedVideoURL != nil,
                    isCurrent: importManager.isDownloading
                )
                
                YouTubeStatusConnector()
                
                YouTubeStatusStep(
                    icon: "scissors",
                    title: "Trim",
                    isCompleted: false,
                    isCurrent: importManager.downloadedVideoURL != nil && !isProcessing
                )
                
                YouTubeStatusConnector()
                
                YouTubeStatusStep(
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
}

struct YouTubeStatusStep: View {
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

struct YouTubeStatusConnector: View {
    var body: some View {
        Rectangle()
            .fill(.gray.opacity(0.3))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    YouTubeStatusSection(
        youtubeURL: "https://youtube.com/watch?v=123",
        importManager: YouTubeImportManager(),
        showingTimeSelector: false,
        isProcessing: false
    )
    .padding()
}
