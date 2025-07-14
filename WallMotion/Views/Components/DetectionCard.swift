//
//  DetectionCard.swift
//  WallMotion
//
//  Created by Václav Blaha on 13.07.2025.
//

import SwiftUI

struct DetectionCard: View {
    let detectedWallpaper: String
    private let wallpaperPath = "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if detectedWallpaper.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Detecting...")
                        .foregroundColor(.secondary)
                }
                .frame(height: 80)
            } else if detectedWallpaper.contains("No wallpaper") || detectedWallpaper.contains("Error") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Setup Required")
                            .fontWeight(.semibold)
                    }
                    
                    Text("Set a video wallpaper in System Settings first")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 80)
            } else {
                HStack(spacing: 12) {
                    // Wallpaper preview
                    WallpaperPreview(wallpaperName: detectedWallpaper, wallpaperPath: wallpaperPath)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ready")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        Text(detectedWallpaper)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                        
                        Text("Live wallpaper detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
