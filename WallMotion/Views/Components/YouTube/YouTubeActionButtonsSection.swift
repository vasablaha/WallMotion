//
//  YouTubeActionButtonsSection.swift
//  WallMotion
//
//  Action buttons section with navigation-style buttons and proper disable during processing
//

import SwiftUI

struct YouTubeActionButtonsSection: View {
    let showingTimeSelector: Bool
    let hasDownloadedVideo: Bool
    let isProcessing: Bool
    let onProcessVideo: () -> Void
    let onStartOver: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                if showingTimeSelector {
                    Button(action: {
                        if !isProcessing {
                            onProcessVideo()
                        }
                    }) {
                        HStack {
                            Image(systemName: "scissors")
                                .foregroundColor(isProcessing ? .gray : .green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Process Video")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(isProcessing ? .gray : .primary)
                                
                                Text(isProcessing ? "Processing..." : "Trim & prepare for wallpaper")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isProcessing ? Color.gray.opacity(0.1) : Color.green.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isProcessing ? Color.gray.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isProcessing)
                }
                
                if hasDownloadedVideo {
                    Button(action: {
                        if !isProcessing {
                            onStartOver()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(isProcessing ? .gray : .red)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start Over")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(isProcessing ? .gray : .primary)
                                
                                Text(isProcessing ? "Please wait..." : "Reset and choose new video")
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
                                .fill(isProcessing ? Color.gray.opacity(0.1) : Color.red.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isProcessing ? Color.gray.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isProcessing)
                }
            }
            
            // Processing warning
            if isProcessing {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("Please wait while the video is being processed. Do not close the app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
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
}

#Preview {
    VStack(spacing: 20) {
        Text("Normal State")
            .font(.headline)
        
        YouTubeActionButtonsSection(
            showingTimeSelector: true,
            hasDownloadedVideo: true,
            isProcessing: false,
            onProcessVideo: {},
            onStartOver: {}
        )
        
        Text("Processing State")
            .font(.headline)
        
        YouTubeActionButtonsSection(
            showingTimeSelector: true,
            hasDownloadedVideo: true,
            isProcessing: true,
            onProcessVideo: {},
            onStartOver: {}
        )
    }
    .padding()
}
