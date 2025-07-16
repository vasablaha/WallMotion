//
//  YouTubeStatusSection.swift
//  WallMotion
//
//  Status section with loading state for video info fetch
//

import SwiftUI

struct YouTubeStatusSection: View {
    let youtubeURL: String
    let importManager: YouTubeImportManager
    let showingTimeSelector: Bool
    let isProcessing: Bool
    let isFetchingVideoInfo: Bool  // NEW: Loading state for info fetch
    
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
                    isCurrent: youtubeURL.isEmpty || !importManager.validateYouTubeURL(youtubeURL),
                    isLoading: false
                )
                
                YouTubeStatusConnector()
                
                YouTubeStatusStep(
                    icon: "info.circle",
                    title: "Info",
                    isCompleted: importManager.videoInfo != nil,
                    isCurrent: !youtubeURL.isEmpty && importManager.validateYouTubeURL(youtubeURL) && importManager.videoInfo == nil,
                    isLoading: isFetchingVideoInfo  // NEW: Show loading for info step
                )
                
                YouTubeStatusConnector()
                
                YouTubeStatusStep(
                    icon: "arrow.down.circle",
                    title: "Download",
                    isCompleted: importManager.downloadedVideoURL != nil,
                    isCurrent: importManager.isDownloading,
                    isLoading: importManager.isDownloading
                )
                
                YouTubeStatusConnector()
                
                YouTubeStatusStep(
                    icon: "scissors",
                    title: "Trim",
                    isCompleted: false,
                    isCurrent: importManager.downloadedVideoURL != nil && !isProcessing,
                    isLoading: false
                )
                
                YouTubeStatusConnector()
                
                YouTubeStatusStep(
                    icon: "checkmark.circle",
                    title: "Ready",
                    isCompleted: false,
                    isCurrent: isProcessing,
                    isLoading: isProcessing
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
    let isLoading: Bool  // NEW: Loading state
    
    var body: some View {
        VStack(spacing: 4) {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(
                            isCompleted ? .green :
                            isCurrent ? .blue : .gray
                        )
                        .frame(width: 32, height: 32)
                }
            }
            .background(
                Circle()
                    .fill(
                        isCompleted ? .green.opacity(0.2) :
                        isCurrent || isLoading ? .blue.opacity(0.2) : .gray.opacity(0.1)
                    )
            )
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(
                    isCompleted ? .green :
                    isCurrent || isLoading ? .blue : .gray
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
    VStack(spacing: 20) {
        Text("Normal State")
            .font(.headline)
        
        YouTubeStatusSection(
            youtubeURL: "https://youtube.com/watch?v=123",
            importManager: YouTubeImportManager(),
            showingTimeSelector: false,
            isProcessing: false,
            isFetchingVideoInfo: false
        )
        
        Text("Loading Info State")
            .font(.headline)
        
        YouTubeStatusSection(
            youtubeURL: "https://youtube.com/watch?v=123",
            importManager: YouTubeImportManager(),
            showingTimeSelector: false,
            isProcessing: false,
            isFetchingVideoInfo: true
        )
    }
    .padding()
}
