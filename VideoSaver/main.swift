//
// VideoSaver/main.swift - MINIMÁLNÍ - jen killall WallpaperAgent
// Nahraďte CELÝ obsah VideoSaver/main.swift tímto kódem
//

import Foundation
import Cocoa

class VideoSaverAgent {
    private let wallpaperPath = "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"
    
    func run() {
        print("🚀 VideoSaverAgent started - version 1.6 (Killall Only)")
        
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
            print("💻 Mac woke up - performing WallpaperAgent restart")
            self.performSimpleRestart()
        }
        
        // Monitor pro screen unlock
        let notificationCenter = DistributedNotificationCenter.default()
        notificationCenter.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔓 Screen unlocked - performing WallpaperAgent restart")
            self.performSimpleRestart()
        }
        
        // Dodatečné monitory
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("👀 Screens woke up - performing WallpaperAgent restart")
            self.performSimpleRestart()
        }
        
        print("✅ System event monitoring configured")
    }
    
    // ✅ NEJJEDNODUŠŠÍ MOŽNÁ METODA - jen killall
    private func performSimpleRestart() {
        // Zkontroluj jestli máme custom wallpapers
        guard hasCustomWallpapers() else {
            print("ℹ️ No custom wallpapers found, skipping restart")
            return
        }
        
        print("🔄 Performing simple WallpaperAgent restart...")
        
        DispatchQueue.global(qos: .background).async {
            // Jen killall WallpaperAgent - nic víc!
            let killResult = self.runShellCommand("killall", arguments: ["WallpaperAgent"])
            print("🔄 WallpaperAgent restart result: \(killResult.isEmpty ? "OK" : killResult)")
        }
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
            // Absolute path
            task.executableURL = URL(fileURLWithPath: command)
            task.arguments = arguments
        } else {
            // Command in PATH - use /usr/bin/env
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
