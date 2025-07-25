//
//  YouTubeProcessingSection.swift
//  WallMotion
//
//  Enhanced Processing section for YouTube Import with better re-encoding feedback
//

import SwiftUI

struct YouTubeProcessingSection: View {
    let progress: Double
    let message: String
    
    @State private var rotationAngle: Double = 0
    
    // ✅ Jednoduchá logika pro rozpoznání spineru
    private var shouldShowSpinner: Bool {
        message.contains("Getting video info") ||
        message.contains("Analyzing") ||
        message.contains("Reading video metadata") ||
        message.contains("Preparing optimization")
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // ✅ JASNÉ rozlišení: spinner vs progress bar
            if shouldShowSpinner {
                // Kruhový spinner pro analýzu
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else {
                // Progress bar pro stahování a konverzi
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(height: 6)
            }
            
            // Status zpráva s ikonami
            HStack(spacing: 8) {
                // Ikona podle typu operace
                Group {
                    if shouldShowSpinner {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                            .scaleEffect(1.1)
                    } else if message.contains("Downloading") {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                    } else if message.contains("Optimizing") {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.orange)
                            .rotationEffect(.degrees(rotationAngle))
                            .onAppear {
                                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                                    rotationAngle = 360
                                }
                            }
                    } else if message.contains("completed") || message.contains("successfully") {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(message)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            
            // Progress procenta POUZE pro normální operace
            if !shouldShowSpinner && progress >= 0 {
                HStack {
                    Text("\(Int(progress * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}


