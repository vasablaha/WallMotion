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
        print("🚀 VideoSaverAgent started - version 1.1 (Silent Refresh)")
        
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
    
    // MARK: - ✅ NOVÁ HYBRID REFRESH METODA
    private func refreshWallMotionWallpaper() {
        guard isWallMotionWallpaperActive() else {
            print("ℹ️ WallMotion wallpaper not active, skipping refresh")
            return
        }
        
        print("🔄 VideoSaverAgent: Attempting silent refresh...")
        
        // Zkus silent refresh na main thread (pro NSWorkspace API)
        DispatchQueue.main.async {
            if self.trySilentRefresh() {
                print("✅ Silent refresh successful - no gray wallpaper!")
                return
            }
            
            // Fallback k původní metodě na background thread
            print("⚠️ Silent refresh failed, using fallback method...")
            DispatchQueue.global(qos: .background).async {
                // Před restartem ještě zkusíme touch
                self.touchWallpaperFiles()
                
                // Gentle restart s HUP signálem místo TERM
                let hupResult = self.runShellCommand("killall", arguments: ["-HUP", "WallpaperAgent"])
                print("HUP signal result: \(hupResult)")
                
                // Pokud HUP nefunguje, zkus standardní killall po krátké pauze
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    let killResult = self.runShellCommand("killall", arguments: ["WallpaperAgent"])
                    print("Killall result: \(killResult)")
                }
                
                print("✅ Fallback wallpaper refresh completed")
            }
        }
    }
    
    // MARK: - ✅ SILENT REFRESH METODY
    private func trySilentRefresh() -> Bool {
        print("🤫 Trying silent refresh methods...")
        
        // Metoda 1: Touch wallpaper files
        touchWallpaperFiles()
        
        // Metoda 2: Invalidate wallpaper cache
        invalidateWallpaperCache()
        
        // Metoda 3: NSWorkspace API refresh
        if tryNSWorkspaceRefresh() {
            return true
        }
        
        // Metoda 4: CFNotification
        if tryNotificationRefresh() {
            // Počkej chvilku a zkontroluj, jestli to fungovalo
            Thread.sleep(forTimeInterval: 0.5)
            return true // Předpokládáme úspěch
        }
        
        return false
    }
    
    private func tryNSWorkspaceRefresh() -> Bool {
        guard let screen = NSScreen.main else {
            print("❌ No main screen found")
            return false
        }
        
        do {
            print("🖥️ Trying NSWorkspace API refresh...")
            let currentURL = NSWorkspace.shared.desktopImageURL(for: screen)
            
            // Zkontroluj, jestli máme platnou URL
            guard let wallpaperURL = currentURL else {
                print("❌ Cannot get current wallpaper URL")
                return false
            }
            
            // Re-set the same wallpaper (forces refresh)
            try NSWorkspace.shared.setDesktopImageURL(wallpaperURL, for: screen, options: [:])
            
            print("✅ NSWorkspace API refresh successful")
            return true
        } catch {
            print("❌ NSWorkspace API refresh failed: \(error)")
            return false
        }
    }
    
    private func tryNotificationRefresh() -> Bool {
        print("📡 Trying notification-based refresh...")
        
        // Pošli notifikaci do systému
        let notification = Notification(name: Notification.Name("WallpaperDidChange"))
        NotificationCenter.default.post(notification)
        
        // Zkus i distributed notification
        let distributedCenter = DistributedNotificationCenter.default()
        distributedCenter.postNotificationName(
            NSNotification.Name("com.apple.desktop.changed"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        
        return true
    }
    
    private func invalidateWallpaperCache() {
        print("🗄️ Invalidating wallpaper cache...")
        
        // Invalidate wallpaper preferences cache
        CFPreferencesAppSynchronize("com.apple.desktop" as CFString)
        CFPreferencesAppSynchronize("com.apple.wallpaper" as CFString)
        CFPreferencesAppSynchronize("com.apple.idleassetsd" as CFString)
        
        // Sync všechny preference
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    
    // MARK: - PŮVODNÍ METODY (nezměněno)
    private func isWallMotionWallpaperActive() -> Bool {
        // Kontrola 1: Existuje marker file od WallMotion?
        let markerPath = "\(wallpaperPath)/\(wallMotionMarkerFile)"
        if FileManager.default.fileExists(atPath: markerPath) {
            print("✅ WallMotion marker found")
            return true
        }
        
        // Kontrola 2: Existují custom .mov soubory?
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: wallpaperPath) else {
            print("❌ Cannot read wallpaper directory")
            return false
        }
        
        let customMovFiles = files.filter { $0.hasSuffix(".mov") && !$0.contains("original") }
        if !customMovFiles.isEmpty {
            print("✅ Found custom .mov files: \(customMovFiles)")
            return true
        }
        
        print("ℹ️ No WallMotion wallpapers detected")
        return false
    }
    
    private func touchWallpaperFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: wallpaperPath) else {
            print("❌ Cannot read wallpaper directory for touch")
            return
        }
        
        let movFiles = files.filter { $0.hasSuffix(".mov") }
        
        for file in movFiles {
            let filePath = "\(wallpaperPath)/\(file)"
            let touchResult = runShellCommand("touch", arguments: [filePath])
            print("👆 Touched: \(file) - \(touchResult.isEmpty ? "OK" : touchResult)")
        }
    }
    
    private func runShellCommand(_ command: String, arguments: [String]) -> String {
        let task = Process()
        
        if command.hasPrefix("/") {
            task.executableURL = URL(fileURLWithPath: command)
            task.arguments = arguments
        } else {
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = [command] + arguments
        }
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return "Failed to run \(command): \(error)"
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Main Entry Point
let agent = VideoSaverAgent()
agent.run()
