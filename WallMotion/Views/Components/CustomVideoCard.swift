//
//  CustomVideoCard.swift
//  WallMotion
//
//  Created by Václav Blaha on 13.07.2025.
//

import SwiftUI

struct CustomVideoCard: View {
    let videoURL: URL
    
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "video.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("Custom Video")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                )
            
            VStack(spacing: 8) {
                Text(videoURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(videoURL.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.blue.opacity(0.5), lineWidth: 2)
                )
        )
    }
}
