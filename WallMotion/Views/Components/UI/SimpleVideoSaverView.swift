//
//  SimpleVideoSaverView.swift
//  WallMotion
//
//  Created by Šimon Filípek on 26.07.2025.
//


//
//  SimpleVideoSaverView.swift
//  WallMotion
//
//  Jednoduchý toggle pro VideoSaver Agent
//

import SwiftUI

struct SimpleVideoSaverView: View {
    @StateObject private var videoSaverManager = SimpleVideoSaverManager()
    @State private var showTooltip = false
    @State private var hoverTimer: Timer?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header s toggle
            HStack {
                Image(systemName: videoSaverManager.isVideoSaverInstalled && videoSaverManager.isVideoSaverEnabled ? 
                      "checkmark.circle.fill" : "play.circle")
                    .foregroundColor(videoSaverManager.getStatusColor())
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("VideoSaver Agent")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Button(action: {
                            showTooltip.toggle()
                        }) {
                            Image(systemName: "questionmark.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { isHovering in
                            handleHover(isHovering)
                        }
                        .popover(isPresented: $showTooltip, arrowEdge: .bottom) {
                            tooltipView
                                .onHover { isHovering in
                                    handleHover(isHovering)
                                }
                        }
                    }
                    
                    Text(videoSaverManager.getStatusText())
                        .font(.caption)
                        .foregroundColor(videoSaverManager.getStatusColor())
                }
                
                Spacer()
                
                // Toggle switch
                if !videoSaverManager.isTogglingAgent {
                    Toggle("", isOn: $videoSaverManager.isVideoSaverEnabled)
                        .toggleStyle(SwitchToggleStyle())
                        .disabled(videoSaverManager.isTogglingAgent)
                        .onChange(of: videoSaverManager.isVideoSaverEnabled) { newValue in
                            videoSaverManager.toggleVideoSaverAgent(newValue)
                        }
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Popis
            Text(videoSaverManager.getDescriptionText())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            // Status zpráva
            if !videoSaverManager.videoSaverMessage.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text(videoSaverManager.videoSaverMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? 
                     Color.black.opacity(0.3) : Color.white.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Tooltip View
    
    private var tooltipView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("VideoSaver Agent - Auto Wallpaper Refresh")
                    .font(.headline)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 10) {
                    Group {
                        Text("🎬 THE PROBLEM:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("macOS sometimes 'freezes' live wallpapers after your Mac wakes up from sleep. The system doesn't always properly refresh video wallpapers.")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("🔧 THE SOLUTION:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("VideoSaver Agent runs in the background and automatically refreshes wallpapers when your Mac wakes up. Works even when WallMotion is closed.")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("⚡ KEY FEATURES:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("• Runs independently as background process\n• Minimal system impact\n• Starts automatically on Mac startup\n• No internet required\n• Can be disabled anytime")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("💡 RECOMMENDATION:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Keep enabled for reliable wallpaper experience, especially if you close WallMotion frequently.")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }
    
    // MARK: - Helper Methods
    
    private func handleHover(_ isHovering: Bool) {
        hoverTimer?.invalidate()
        
        if isHovering {
            showTooltip = true
        } else {
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                showTooltip = false
            }
        }
    }
}