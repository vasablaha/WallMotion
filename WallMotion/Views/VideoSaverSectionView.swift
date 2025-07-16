//
//  VideoSaverSectionView.swift
//  WallMotion
//
//  Created by Šimon Filípek on 16.07.2025.
//


//
//  VideoSaverSectionView.swift
//  WallMotion
//
//  Standalone VideoSaver UI section
//

import SwiftUI

struct VideoSaverSectionView: View {
    @ObservedObject var videoSaverManager: VideoSaverManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showTooltip = false
    @State private var hoverTimer: Timer?  // ✅ PŘIDEJ TIMER
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: videoSaverManager.isVideoSaverInstalled && videoSaverManager.isVideoSaverEnabled ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundColor(videoSaverManager.isVideoSaverInstalled && videoSaverManager.isVideoSaverEnabled ? .green : .orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("VideoSaverAgent")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        // ✅ OPRAVENÝ INFO BUTTON:
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
                                .onHover { isHovering in  // ✅ HOVER NA POPOVER
                                    handleHover(isHovering)
                                }
                        }
                    }
                    
                    Text(videoSaverManager.getVideoSaverStatusText())
                        .font(.caption)
                        .foregroundColor(videoSaverManager.getVideoSaverStatusColor())
                }
                
                Spacer()
                
                // Toggle switch...
                if !videoSaverManager.isTogglingAgent {
                    Toggle("", isOn: $videoSaverManager.isVideoSaverEnabled)
                        .toggleStyle(SwitchToggleStyle())
                        .disabled(videoSaverManager.isTogglingAgent)
                        .onChange(of: videoSaverManager.isVideoSaverEnabled) { newValue in
                            videoSaverManager.handleVideoSaverToggle(newValue)
                        }
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Text(videoSaverManager.getVideoSaverDescriptionText())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            if !videoSaverManager.videoSaverMessage.isEmpty {
                Text(videoSaverManager.videoSaverMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            videoSaverManager.setupVideoSaver()
        }
    }
    
    // ✅ NOVÁ HOVER HANDLING FUNKCE:
    private func handleHover(_ isHovering: Bool) {
        hoverTimer?.invalidate()
        
        if isHovering {
            showTooltip = true
        } else {
            // Delay před zavřením tooltip - dá čas na přesun myši
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                showTooltip = false
            }
        }
    }
    
    private var tooltipView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("VideoSaverAgent - What is this?")
                    .font(.headline)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 10) {
                    Group {
                        Text("🎬 THE PROBLEM:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("macOS sometimes 'freezes' live wallpapers after your Mac wakes up from sleep. The system doesn't always properly refresh video wallpapers when returning from sleep mode.")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("🔧 THE SOLUTION:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("VideoSaverAgent is a lightweight background process that automatically detects when your Mac wakes up and refreshes the wallpaper system to ensure your custom videos continue playing smoothly.")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("🎯 WHEN TO USE:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Enable this if you notice that your custom video wallpapers stop playing after sleep/wake cycles, appear frozen or static after unlocking, or need manual refresh to work properly.")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("🔒 PRIVACY & SECURITY:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("No internet connection required, no personal data collected, uses only macOS system APIs, and can be disabled anytime.")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Group {
                        Text("💡 TIP:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Most users benefit from keeping this enabled, but you can disable it if you don't experience wallpaper issues.")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 400, height: 350)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
