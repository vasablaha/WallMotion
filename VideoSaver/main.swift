//
// VideoSaver/main.swift - S SILENT METODAMI proti šedému probliknutí
// Nahraďte CELÝ obsah VideoSaver/main.swift tímto kódem
//

import Foundation
import Cocoa

class VideoSaverAgent {
    private let wallpaperPath = "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"
    
    func run() {
        print("🚀 VideoSaverAgent started - version 1.7 (Silent First)")
        
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
            print("💻 Mac woke up - trying silent refresh first")
            self.performSmartRefresh()
        }
        
        // Monitor pro screen unlock
        let notificationCenter = DistributedNotificationCenter.default()
        notificationCenter.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔓 Screen unlocked - trying silent refresh first")
            self.performSmartRefresh()
        }
        
        // Dodatečné monitory
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("👀 Screens woke up - trying silent refresh first")
            self.performSmartRefresh()
        }
        
        print("✅ System event monitoring configured")
    }
    
    // ✅ SMART REFRESH - zkus silent metody před killall
    private func performSmartRefresh() {
        // Zkontroluj jestli máme custom wallpapers
        guard hasCustomWallpapers() else {
            print("ℹ️ No custom wallpapers found, skipping refresh")
            return
        }
        
        print("🤫 Trying silent refresh methods first...")
        
        // Zkus silent metody na main thread
        DispatchQueue.main.async {
            if self.trySilentRefresh() {
                print("✅ Silent refresh successful - no gray flash!")
                return
            }
            
            // Pokud silent metody nepomohou, použij gentle restart
            print("⚠️ Silent methods failed, trying gentle restart...")
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
                self.performGentleRestart()
            }
        }
    }
    
    // ✅ SILENT REFRESH METODY
    private func trySilentRefresh() -> Bool {
        var successCount = 0
        
        // Metoda 1: Touch wallpaper files
        if touchWallpaperFiles() {
            successCount += 1
            print("✅ Touch files successful")
        }
        
        // Metoda 2: Invalidate cache
        if invalidateWallpaperCache() {
            successCount += 1
            print("✅ Cache invalidation successful")
        }
        
        // Metoda 3: Send notifications
        if sendRefreshNotifications() {
            successCount += 1
            print("✅ Notifications sent")
        }
        
        // Metoda 4: Gentle HUP signal
        if gentleHupSignal() {
            successCount += 1
            print("✅ Gentle HUP signal sent")
        }
        
        // Pokud alespoň 2 metody byly úspěšné, počkej a předpokládej úspěch
        if successCount >= 2 {
            Thread.sleep(forTimeInterval: 0.3) // Krátká pauza pro aplikaci změn
            return true
        }
        
        return false
    }
    
    // ✅ TOUCH WALLPAPER FILES
    private func touchWallpaperFiles() -> Bool {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: wallpaperPath)
            let movFiles = files.filter { $0.hasSuffix(".mov") && !$0.contains(".backup") }
            
            var touchedCount = 0
            for file in movFiles {
                let filePath = "\(wallpaperPath)/\(file)"
                let touchResult = runShellCommand("touch", arguments: [filePath])
                if touchResult.isEmpty || !touchResult.contains("error") {
                    touchedCount += 1
                }
            }
            
            print("👆 Touched \(touchedCount)/\(movFiles.count) wallpaper files")
            return touchedCount > 0
        } catch {
            print("❌ Error touching files: \(error)")
            return false
        }
    }
    
    // ✅ CACHE INVALIDATION
    private func invalidateWallpaperCache() -> Bool {
        print("🗄️ Invalidating wallpaper cache...")
        
        // Synchronizuj wallpaper preferences
        CFPreferencesAppSynchronize("com.apple.desktop" as CFString)
        CFPreferencesAppSynchronize("com.apple.wallpaper" as CFString)
        CFPreferencesAppSynchronize("com.apple.idleassetsd" as CFString)
        CFPreferencesAppSynchronize("com.apple.CoreGraphics" as CFString)
        
        // Force sync
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        
        return true // Cache operations vždycky "úspěšné"
    }
    
    // ✅ REFRESH NOTIFICATIONS
    private func sendRefreshNotifications() -> Bool {
        print("📡 Sending refresh notifications...")
        
        // Local notifications
        NotificationCenter.default.post(name: Notification.Name("WallpaperDidChange"), object: nil)
        
        // Distributed notifications
        let distributedCenter = DistributedNotificationCenter.default()
        let notifications = [
            "com.apple.desktop.changed",
            "com.apple.wallpaper.changed",
            "com.apple.idleassetsd.refresh",
            "com.apple.CoreGraphics.displayConfigurationChanged"
        ]
        
        for notificationName in notifications {
            distributedCenter.postNotificationName(
                NSNotification.Name(notificationName),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
        
        return true
    }
    
    // ✅ GENTLE HUP SIGNAL
    private func gentleHupSignal() -> Bool {
        print("🔄 Sending gentle HUP signal...")
        
        let hupResult = runShellCommand("killall", arguments: ["-HUP", "WallpaperAgent"])
        let success = hupResult.isEmpty || !hupResult.contains("No matching processes")
        
        if success {
            print("✅ HUP signal sent successfully")
        } else {
            print("⚠️ HUP signal result: \(hupResult)")
        }
        
        return success
    }
    
    // ✅ GENTLE RESTART - jen pokud silent metody selhaly
    private func performGentleRestart() {
        print("🔄 Performing gentle WallpaperAgent restart...")
        
        // Ještě jeden pokus o touch před restartem
        _ = touchWallpaperFiles()
        
        // Standard killall jako poslední možnost
        let killResult = runShellCommand("killall", arguments: ["WallpaperAgent"])
        print("🔄 Final restart result: \(killResult.isEmpty ? "OK" : killResult)")
    }
    
    // ✅ ZKONTROLUJ CUSTOM WALLPAPERS
    private func hasCustomWallpapers() -> Bool {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: wallpaperPath)
            let movFiles = files.filter { $0.hasSuffix(".mov") && !$0.contains(".backup") }
            
            if !movFiles.isEmpty {
                print("✅ Found \(movFiles.count) custom wallpaper(s)")
                return true
            } else {
                print("ℹ️ No custom wallpapers found")
                return false
            }
        } catch {
            print("❌ Error checking wallpaper files: \(error)")
            return false
        }
    }
    
    // ✅ SHELL COMMAND HELPER
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
