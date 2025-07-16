//
//  YouTubeImportHeader.swift
//  WallMotion
//
//  Header component for YouTube Import
//

import SwiftUI

struct YouTubeImportHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("YouTube Import")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            Text("Download and customize any YouTube video as your wallpaper")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    YouTubeImportHeader()
        .padding()
}
