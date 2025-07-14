//
//  WallpaperPreview.swift
//  WallMotion
//
//  Created by Václav Blaha on 13.07.2025.
//

import SwiftUI

struct WallpaperPreview: View {
    let wallpaperName: String
    let wallpaperPath: String
    @State private var hasPreview = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 60, height: 45)
            .overlay(
                Group {
                    if hasPreview {
                        // If we could load the actual video preview, show it here
                        // For now, show a nice icon
                        Image(systemName: "play.rectangle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            )
            .onAppear {
                checkForPreview()
            }
    }
    
    private func checkForPreview() {
        let filePath = "\(wallpaperPath)/\(wallpaperName).mov"
        hasPreview = FileManager.default.fileExists(atPath: filePath)
    }
}
