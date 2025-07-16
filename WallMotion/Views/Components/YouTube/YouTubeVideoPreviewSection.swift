//
//  YouTubeVideoPreviewSection.swift
//  WallMotion
//
//  Video preview section for YouTube Import
//

import SwiftUI
import AVKit

struct YouTubeVideoPreviewSection: View {
    let videoURL: URL
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Text("Video Downloaded Successfully!")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.gray.opacity(0.3), lineWidth: 1)
                    )
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
    }
}

#Preview {
    YouTubeVideoPreviewSection(
        videoURL: URL(string: "https://example.com/video.mp4")!
    )
    .padding()
}
