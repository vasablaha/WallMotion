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
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress bar s animací
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.3), value: progress)
            
            // Status message s ikonami pro různé fáze
            HStack(spacing: 8) {
                // Ikona podle fáze
                Group {
                    if message.contains("Downloading") {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                    } else if message.contains("Converting") || message.contains("H.264") {
                        Image(systemName: "gearshape.2.fill")
                            .foregroundColor(.orange)
                            .rotationEffect(.degrees(progress > 0 ? 360 : 0))
                            .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: progress > 0)
                    } else if message.contains("completed") || message.contains("successful") {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if message.contains("Processing") || message.contains("Trim") {
                        Image(systemName: "scissors")
                            .foregroundColor(.purple)
                    } else {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            // Detailní informace pro uživatele
            if message.contains("Converting") || message.contains("H.264") {
                Text("Converting video to H.264 format for macOS wallpaper compatibility...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else if message.contains("Processing") || message.contains("Trim") {
                Text("Trimming video to selected time range and optimizing for wallpaper...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else if message.contains("Downloading") {
                Text("Downloading video from YouTube in best available quality...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(getStrokeColor().opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // Helper funkce pro barvu podle fáze
    private func getStrokeColor() -> Color {
        if message.contains("Downloading") {
            return .blue
        } else if message.contains("Converting") || message.contains("H.264") {
            return .orange
        } else if message.contains("completed") || message.contains("successful") {
            return .green
        } else if message.contains("Processing") || message.contains("Trim") {
            return .purple
        } else {
            return .blue
        }
    }
}
