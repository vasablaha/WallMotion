//
//  EmptyCustomVideoView.swift
//  WallMotion
//
//  Created by Václav Blaha on 13.07.2025.
//

import SwiftUI

struct EmptyCustomVideoView: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.7))
            
            Text("No Custom Video Selected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose a video file from your computer to use as wallpaper")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Choose Video File", action: action)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.blue.opacity(0.3), lineWidth: 2)
                )
        )
    }
}
