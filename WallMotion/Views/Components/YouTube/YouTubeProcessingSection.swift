//
//  YouTubeProcessingSection.swift
//  WallMotion
//
//  Processing section for YouTube Import
//

import SwiftUI

struct YouTubeProcessingSection: View {
    let progress: Double
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text(message)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 1.5)
                
                HStack {
                    Text("Processing video...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
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
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    YouTubeProcessingSection(
        progress: 0.65,
        message: "Processing video segment..."
    )
    .padding()
}
