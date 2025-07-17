// VideoSaverManager.swift - async oprava

import Foundation
import SwiftUI

class VideoSaverManager: ObservableObject {
    @Published var isVideoSaverInstalled = false
    @Published var videoSaverMessage = ""
    @Published var isVideoSaverEnabled = false
    @Published var isTogglingAgent = false
    
    private let videoSaverInstaller = VideoSaverAgentInstaller()
    private let videoSaverEnabledKey = "VideoSaverAgentEnabled"
    
    init() {
        loadVideoSaverSettings()
    }
    
    // MARK: - Public Methods
    
    func setupVideoSaver() {
        print("🔧 Setting up VideoSaverAgent...")
        loadVideoSaverSettings()
    }
    
    func handleVideoSaverToggle(_ enabled: Bool) {
        print("🔄 VideoSaver toggle changed to: \(enabled)")
        
        // Ulož nastavení
        UserDefaults.standard.set(enabled, forKey: videoSaverEnabledKey)
        isVideoSaverEnabled = enabled
        
        isTogglingAgent = true
        videoSaverMessage = enabled ? "Installing agent..." : "Stopping agent..."
        
        Task {
            let success: Bool
            
            if enabled {
                success = await installAndStartVideoSaverAgent()
            } else {
                success = await stopAndUninstallVideoSaverAgent()
            }
            
            await MainActor.run {
                self.isTogglingAgent = false
                
                if enabled {
                    if success {
                        self.isVideoSaverInstalled = true
                        self.videoSaverMessage = "VideoSaverAgent enabled!"
                        print("✅ VideoSaverAgent enabled successfully")
                    } else {
                        self.isVideoSaverEnabled = false // Vrať toggle zpět
                        self.isVideoSaverInstalled = false
                        self.videoSaverMessage = "Failed to enable agent"
                        print("❌ VideoSaverAgent enable failed")
                    }
                } else {
                    self.isVideoSaverInstalled = false
                    
                    if success {
                        self.videoSaverMessage = "VideoSaverAgent disabled"
                        print("✅ VideoSaverAgent disabled successfully")
                    } else {
                        self.videoSaverMessage = "Failed to disable agent"
                        print("❌ VideoSaverAgent disable failed")
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
    
    // MARK: - UI Helper Methods
    
    func getVideoSaverStatusText() -> String {
        if isTogglingAgent {
            return "Updating..."
        } else if isVideoSaverEnabled && isVideoSaverInstalled {
            return "Auto-refresh active"
        } else if isVideoSaverEnabled && !isVideoSaverInstalled {
            return "Installing..."
        } else {
            return "Auto-refresh disabled"
        }
    }
    
    func getVideoSaverStatusColor() -> Color {
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
    
    func getVideoSaverDescriptionText() -> String {
        if isVideoSaverEnabled {
            return "VideoSaverAgent automatically refreshes your wallpaper when Mac wakes up. Useful for custom wallpapers that may freeze after sleep."
        } else {
            return "VideoSaverAgent is disabled. Enable to automatically refresh wallpapers after sleep/wake cycles."
        }
    }
    
    func getVideoSaverTooltipText() -> String {
        return """
        VideoSaverAgent - What is this?
        
        🎬 THE PROBLEM:
        macOS sometimes "freezes" or "forgets" live wallpapers after your Mac wakes up from sleep. This happens because the system doesn't always properly refresh video wallpapers when returning from sleep mode.
        
        🔧 THE SOLUTION:
        VideoSaverAgent is a lightweight background process that automatically detects when your Mac wakes up and refreshes the wallpaper system to ensure your custom videos continue playing smoothly.
        
        ⚡ HOW IT WORKS:
        • Runs silently in the background (minimal system impact)
        • Monitors sleep/wake events using macOS notifications
        • Automatically refreshes WallpaperAgent when Mac wakes up
        • Only activates when WallMotion wallpapers are detected
        • Operates independently of the main WallMotion app
        
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
        
        💡 TIP: Most users benefit from keeping this enabled, but you can disable it if you don't experience wallpaper issues.
        """
    }
    
    // MARK: - Private Methods
    
    private func loadVideoSaverSettings() {
        // Načti uložené nastavení
        isVideoSaverEnabled = UserDefaults.standard.bool(forKey: videoSaverEnabledKey)
        
        // Zkontroluj aktuální stav agenta
        checkVideoSaverStatus()
    }
    
    // ✅ ZMĚNĚNO NA ASYNC
    private func checkVideoSaverStatus() {
        Task {
            let isRunning = await videoSaverInstaller.isVideoSaverAgentRunning()
            
            await MainActor.run {
                self.isVideoSaverInstalled = isRunning
                
                // Pokud je agent zapnutý v nastavení ale neběží, zkus ho spustit
                if self.isVideoSaverEnabled && !self.isVideoSaverInstalled {
                    print("🔄 VideoSaver enabled but not running - starting...")
                    
                    Task {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        await MainActor.run {
                            self.handleVideoSaverToggle(true)
                        }
                    }
                }
            }
        }
    }
    
    // ✅ ZMĚNĚNO NA ASYNC
    private func installAndStartVideoSaverAgent() async -> Bool {
        return await videoSaverInstaller.installVideoSaverAgent()
    }
    
    // ✅ ZMĚNĚNO NA ASYNC
    private func stopAndUninstallVideoSaverAgent() async -> Bool {
        return await videoSaverInstaller.uninstallVideoSaverAgent()
    }
}
