//
//  YouTubeURLInputSection.swift
//  WallMotion
//
//  URL input section with loading feedback for search button
//

import SwiftUI

struct YouTubeURLInputSection: View {
    @Binding var youtubeURL: String
    let importManager: YouTubeImportManager
    let onFetchVideoInfo: () -> Void
    let isProcessing: Bool
    let isFetchingVideoInfo: Bool  // NEW: Loading state for video info
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("YouTube Video URL")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack {
                    TextField("https://youtube.com/watch?v=...", text: $youtubeURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isProcessing || isFetchingVideoInfo)
                        .onSubmit {
                            if !isProcessing && !isFetchingVideoInfo && importManager.validateYouTubeURL(youtubeURL) {
                                onFetchVideoInfo()
                            }
                        }
                    
                    Button(action: {
                        if !isProcessing && !isFetchingVideoInfo {
                            onFetchVideoInfo()
                        }
                    }) {
                        Group {
                            if isFetchingVideoInfo {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                            }
                        }
                        .foregroundColor(isProcessing || isFetchingVideoInfo ? .gray : .blue)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke((isProcessing || isFetchingVideoInfo ? Color.gray : Color.blue).opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isProcessing || isFetchingVideoInfo || youtubeURL.isEmpty || !importManager.validateYouTubeURL(youtubeURL))
                }
                
                // NEW: Loading feedback text
                if isFetchingVideoInfo {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        
                        Text("Fetching video information...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
            }
            
            VStack(spacing: 16) {
                if !youtubeURL.isEmpty {
                    YouTubeURLValidationFeedback(
                        isValid: importManager.validateYouTubeURL(youtubeURL)
                    )
                }
                
                YouTubeSupportedFormats()
                
                // Processing warning
                if isProcessing {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("Video processing in progress. Please wait before starting a new import.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct YouTubeURLValidationFeedback: View {
    let isValid: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isValid ? Color.green : Color.red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isValid ? "Valid YouTube URL" : "Invalid YouTube URL")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isValid ? Color.green : Color.red)
                
                if !isValid {
                    Text("Please check the URL format")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            createValidationBackground(isValid: isValid)
        )
    }
    
    private func createValidationBackground(isValid: Bool) -> some View {
        let backgroundColor = isValid ? Color.green.opacity(0.1) : Color.red.opacity(0.1)
        let borderColor = isValid ? Color.green.opacity(0.3) : Color.red.opacity(0.3)
        
        return RoundedRectangle(cornerRadius: 10)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}

struct YouTubeSupportedFormats: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Supported URL Formats")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                YouTubeFormatRow(format: "youtube.com/watch?v=VIDEO_ID")
                YouTubeFormatRow(format: "youtu.be/VIDEO_ID")
                YouTubeFormatRow(format: "youtube.com/embed/VIDEO_ID")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct YouTubeFormatRow: View {
    let format: String
    
    var body: some View {
        HStack {
            Image(systemName: "link")
                .foregroundColor(.blue)
                .font(.caption)
            
            Text(format)
                .font(.caption)
               
            
            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Normal State")
            .font(.headline)
        
        YouTubeURLInputSection(
            youtubeURL: .constant("https://youtube.com/watch?v=123"),
            importManager: YouTubeImportManager(),
            onFetchVideoInfo: {},
            isProcessing: false,
            isFetchingVideoInfo: false
        )
        
        Text("Loading State")
            .font(.headline)
        
        YouTubeURLInputSection(
            youtubeURL: .constant("https://youtube.com/watch?v=123"),
            importManager: YouTubeImportManager(),
            onFetchVideoInfo: {},
            isProcessing: false,
            isFetchingVideoInfo: true
        )
        
        Text("Processing State")
            .font(.headline)
        
        YouTubeURLInputSection(
            youtubeURL: .constant("https://youtube.com/watch?v=123"),
            importManager: YouTubeImportManager(),
            onFetchVideoInfo: {},
            isProcessing: true,
            isFetchingVideoInfo: false
        )
    }
    .padding()
}
