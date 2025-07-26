//
//  SimpleVideoSaverManager.swift
//  WallMotion
//
//  Created by Šimon Filípek on 26.07.2025.
//


//
//  SimpleVideoSaverManager.swift
//  WallMotion
//
//  Jednoduchý manager jen pro zapnutí/vypnutí VideoSaver agenta
//

import Foundation
import SwiftUI

class SimpleVideoSaverManager: ObservableObject {
    @Published var isVideoSaverEnabled = false
    @Published var isVideoSaverInstalled = false
    @Published var videoSaverMessage = ""
    @Published var isTogglingAgent = false
    
    private let videoSaverInstaller = SimpleVideoSaverAgentInstaller()
    private let videoSaverEnabledKey = "VideoSaverAgentEnabled"
    
    init() {
        loadSettings()
        checkVideoSaverStatus()
    }
    
    // MARK: - Setup
    
    private func loadSettings() {
        isVideoSaverEnabled = UserDefaults.standard.bool(forKey: videoSaverEnabledKey)
        print("🔧 VideoSaver agent enabled: \(isVideoSaverEnabled)")
    }
    
    private func checkVideoSaverStatus() {
        Task {
            let isRunning = await videoSaverInstaller.isVideoSaverAgentRunning()
            
            await MainActor.run {
                self.isVideoSaverInstalled = isRunning
                
                // Pokud má být zapnutý ale neběží, zkus ho spustit
                if self.isVideoSaverEnabled && !self.isVideoSaverInstalled {
                    print("🔄 VideoSaver should be running but isn't - starting...")
                    Task {
                        await self.startVideoSaverAgent()
                    }
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    func toggleVideoSaverAgent(_ enabled: Bool) {
        print("🔄 VideoSaver toggle: \(enabled)")
        
        isVideoSaverEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: videoSaverEnabledKey)
        
        isTogglingAgent = true
        videoSaverMessage = enabled ? "Installing VideoSaver Agent..." : "Stopping VideoSaver Agent..."
        
        Task {
            let success: Bool
            
            if enabled {
                success = await startVideoSaverAgent()
            } else {
                success = await stopVideoSaverAgent()
            }
            
            await MainActor.run {
                self.isTogglingAgent = false
                
                if enabled {
                    if success {
                        self.isVideoSaverInstalled = true
                        self.videoSaverMessage = "VideoSaver Agent activated!"
                        print("✅ VideoSaver Agent started successfully")
                    } else {
                        self.isVideoSaverEnabled = false // Vrať toggle zpět
                        self.isVideoSaverInstalled = false
                        self.videoSaverMessage = "Failed to start VideoSaver Agent"
                        print("❌ VideoSaver Agent start failed")
                    }
                } else {
                    self.isVideoSaverInstalled = false
                    
                    if success {
                        self.videoSaverMessage = "VideoSaver Agent stopped"
                        print("✅ VideoSaver Agent stopped successfully")
                    } else {
                        self.videoSaverMessage = "Failed to stop VideoSaver Agent"
                        print("❌ VideoSaver Agent stop failed")
                    }
                }
                
                // Vymaž zprávu po 3 sekundách
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        self.videoSaverMessage = ""
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func startVideoSaverAgent() async -> Bool {
        return await videoSaverInstaller.installVideoSaverAgent()
    }
    
    private func stopVideoSaverAgent() async -> Bool {
        return await videoSaverInstaller.uninstallVideoSaverAgent()
    }
    
    // MARK: - UI Helper Methods
    
    func getStatusText() -> String {
        if isTogglingAgent {
            return "Updating..."
        } else if isVideoSaverEnabled && isVideoSaverInstalled {
            return "VideoSaver Agent Running"
        } else if isVideoSaverEnabled && !isVideoSaverInstalled {
            return "Starting VideoSaver Agent..."
        } else {
            return "VideoSaver Agent Disabled"
        }
    }
    
    func getStatusColor() -> Color {
        if isTogglingAgent {
            return .blue
        } else if isVideoSaverEnabled && isVideoSaverInstalled {
            return .green
        } else if isVideoSaverEnabled && !isVideoSaverInstalled {
            return .orange
        } else {
            return .secondary
        }
    }
    
    func getDescriptionText() -> String {
        if isVideoSaverEnabled {
            return "VideoSaver Agent automatically refreshes your wallpaper when Mac wakes up from sleep. Runs independently even when the app is closed."
        } else {
            return "VideoSaver Agent is disabled. Your wallpapers may freeze after sleep/wake cycles until manually refreshed."
        }
    }
    
    func getTooltipText() -> String {
        return """
        VideoSaver Agent - What is this?
        
        🎬 THE PROBLEM:
        macOS sometimes "freezes" or "forgets" live wallpapers after your Mac wakes up from sleep. This happens because the system doesn't always properly refresh video wallpapers when returning from sleep mode.
        
        🔧 THE SOLUTION:
        VideoSaver Agent is a lightweight background process that automatically detects when your Mac wakes up and refreshes the wallpaper system to ensure your custom videos continue playing smoothly.
        
        ⚡ HOW IT WORKS:
        • Runs silently in the background (minimal system impact)
        • Monitors sleep/wake events using macOS notifications  
        • Automatically refreshes wallpapers when Mac wakes up
        • Only activates when WallMotion wallpapers are detected
        • Operates independently of the main WallMotion app
        • Starts automatically on Mac startup when enabled
        
        🎯 WHEN TO USE:
        Enable this if you notice that your custom video wallpapers:
        • Stop playing after sleep/wake cycles
        • Appear frozen or static after unlocking
        • Need manual refresh to work properly
        
        🔒 PRIVACY & SECURITY:
        • No internet connection required
        • No personal data collected
        • Uses only macOS system APIs
        • Can be disabled anytime
        
        💡 RECOMMENDATION: 
        Keep this enabled for the best wallpaper experience, especially if you want reliable wallpapers without keeping the main app open.
        """
    }
}
