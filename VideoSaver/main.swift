//
//  main.swift
//  VideoSaverAgent
//
//  Created by WallMotion
//

import Foundation
import Cocoa

class VideoSaverAgent {
    private let wallpaperPath = "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"
    private let wallMotionMarkerFile = "wallmotion_active"
    
    func run() {
        print("🚀 VideoSaverAgent started - version 1.0")
        
        // Prvotní refresh při spuštění
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.refreshWallMotionWallpaper()
        }
        
        // Nastavení notifikací pro wake/sleep
        setupSystemEventMonitoring()
        
        // Keep agent running
        print("✅ VideoSaverAgent running in background...")
        RunLoop.main.run()
    }
    
    private func setupSystemEventMonitoring() {
        // Monitor pro wake události
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("💻 Mac woke up - refreshing wallpaper")
            self.refreshWallMotionWallpaper()
        }
        
        // Monitor pro screen unlock
        let notificationCenter = DistributedNotificationCenter.default()
        notificationCenter.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔓 Screen unlocked - refreshing wallpaper")
            self.refreshWallMotionWallpaper()
        }
        
        // Dodatečný monitor pro sleep/wake přes IOKit
        setupIOKitMonitoring()
        
        // Periodický refresh každých 10 minut (jako backup)
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            print("⏰ Periodic refresh")
            self?.refreshWallMotionWallpaper()
        }
        
        print("✅ System event monitoring configured")
    }
    
    private func setupIOKitMonitoring() {
        // Jednoduší přístup bez IOKit - použijeme jen NSWorkspace
        print("✅ Using NSWorkspace monitoring only")
        
        // Dodatečný monitor pro screen saver události
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("💤 Screens did sleep")
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("👀 Screens did wake - refreshing wallpaper")
            self.refreshWallMotionWallpaper()
        }
    }
    
    private func refreshWallMotionWallpaper() {
        guard isWallMotionWallpaperActive() else {
            print("ℹ️ WallMotion wallpaper not active, skipping refresh")
            return
        }
        
        print("🔄 VideoSaverAgent: Refreshing WallMotion wallpaper...")
        
        DispatchQueue.global(qos: .background).async {
            // Refresh WallpaperAgent
            self.runShellCommand("killall", arguments: ["WallpaperAgent"])
            
            // Touch wallpaper files
            self.touchWallpaperFiles()
            
            print("✅ Wallpaper refresh completed")
        }
    }
    
    private func isWallMotionWallpaperActive() -> Bool {
        // Kontrola 1: Existuje marker file od WallMotion?
        let markerPath = "\(wallpaperPath)/\(wallMotionMarkerFile)"
        if FileManager.default.fileExists(atPath: markerPath) {
            print("✅ WallMotion marker found")
            return true
        }
        
        // Kontrola 2: Existují custom .mov soubory?
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: wallpaperPath)
            let hasMovFiles = files.contains { $0.hasSuffix(".mov") }
            
            if hasMovFiles {
                let systemFiles = ["4KSDR240FPS.mov", "4KSDR240FPS_SDR.mov"]
                let hasOnlySystemFiles = files.filter { $0.hasSuffix(".mov") }.allSatisfy { systemFiles.contains($0) }
                let isCustomWallpaper = !hasOnlySystemFiles
                
                if isCustomWallpaper {
                    print("✅ Custom wallpaper detected")
                }
                
                return isCustomWallpaper
            }
            
            return false
        } catch {
            print("❌ Error checking wallpaper directory: \(error)")
            return false
        }
    }
    
    private func touchWallpaperFiles() {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: wallpaperPath)
            for file in files where file.hasSuffix(".mov") {
                let filePath = "\(wallpaperPath)/\(file)"
                runShellCommand("touch", arguments: [filePath])
            }
            print("✅ Wallpaper files touched")
        } catch {
            print("❌ Failed to touch wallpaper files: \(error)")
        }
    }
    
    private func runShellCommand(_ command: String, arguments: [String]) {
        let task = Process()
        
        // ✅ OPRAVA: Use executableURL
        if command.hasPrefix("/") {
            task.executableURL = URL(fileURLWithPath: command)
            task.arguments = arguments
        } else {
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = [command] + arguments
        }
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("❌ Failed to run \(command): \(error)")
        }
    }
}

// MAIN ENTRY POINT
print("🚀 Starting VideoSaverAgent...")

// Handle termination gracefully
signal(SIGTERM) { _ in
    print("📱 VideoSaverAgent received SIGTERM, shutting down gracefully...")
    exit(0)
}

signal(SIGINT) { _ in
    print("📱 VideoSaverAgent received SIGINT, shutting down gracefully...")
    exit(0)
}

let agent = VideoSaverAgent()
agent.run()
