//
//  VideoSaverView.swift
//  VideoSaver
//
//  Enhanced version with wallpaper refresh functionality
//

import ScreenSaver
import Foundation

class VideoSaverView: ScreenSaverView {
    private let userDefaults = ScreenSaverDefaults(forModuleWithName: "com.tapp-studio.VideoSaver")!
    private var frameCounter: Int?
    
    // Paths for WallMotion wallpaper detection - kompatibilní s WallpaperManager
    private let wallpaperPath = "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"
    private let wallMotionMarkerFile = "wallmotion_active"
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        setupPlayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupPlayer()
    }
    
    private func setupPlayer() {
        // Screen saver nepoužívá žádné video - jen refreshuje wallpaper
        // Vytvoř prázdný layer pro kompatibilitu
        let emptyLayer = CALayer()
        emptyLayer.frame = bounds
        emptyLayer.backgroundColor = NSColor.clear.cgColor
        self.layer?.addSublayer(emptyLayer)
    }
    
    override func startAnimation() {
        super.startAnimation()
        
        // 🚀 HLAVNÍ FUNKCE: Refresh wallpaper při spuštění screen saver
        refreshWallMotionWallpaper()
    }
    
    override func stopAnimation() {
        super.stopAnimation()
    }
    
    override func animateOneFrame() {
        // Looping je zajištěn AVPlayerLooper
        // Můžeme zde přidat periodickou kontrolu každých X sekund
        
        // Použij instance property místo static
        if frameCounter == nil {
            frameCounter = 0
        }
        frameCounter! += 1
        
        // Každých 30 sekund zkontroluj a refreshni (při 30fps = 900 frames)
        if frameCounter! % 900 == 0 {
            refreshWallMotionWallpaper()
        }
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        layer?.sublayers?.forEach { $0.frame = bounds }
    }
    
    // MARK: - WallMotion Wallpaper Refresh Logic
    
    private func refreshWallMotionWallpaper() {
        guard isWallMotionWallpaperActive() else { return }
        
        print("🔄 VideoSaver: Refreshing WallMotion wallpaper...")
        
        // Spusť refresh synchronně v background
        Task.detached {
            await self.runShellCommand("killall", arguments: ["WallpaperAgent"])
            
            // Dodatečně zkus "touch" wallpaper soubory pro reload
            await self.touchWallpaperFiles()
        }
    }
    
    private func isWallMotionWallpaperActive() -> Bool {
        // Kontrola 1: Existuje marker file od WallMotion?
        let markerPath = "\(wallpaperPath)/\(wallMotionMarkerFile)"
        if FileManager.default.fileExists(atPath: markerPath) {
            return true
        }
        
        // Kontrola 2: Existují .mov soubory v wallpaper adresáři?
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: wallpaperPath)
            let hasMovFiles = files.contains { $0.hasSuffix(".mov") }
            
            // Kontrola 3: Jsou to WallMotion soubory? (nejsou system wallpaper)
            if hasMovFiles {
                // Zkontroluj, jestli není původní system wallpaper
                let systemFiles = ["4KSDR240FPS.mov", "4KSDR240FPS_SDR.mov"]
                let hasOnlySystemFiles = files.filter { $0.hasSuffix(".mov") }.allSatisfy { systemFiles.contains($0) }
                return !hasOnlySystemFiles
            }
            
            return false
        } catch {
            return false
        }
    }
    
    private func touchWallpaperFiles() async {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: wallpaperPath)
            for file in files where file.hasSuffix(".mov") {
                let filePath = "\(wallpaperPath)/\(file)"
                await runShellCommand("touch", arguments: [filePath])
            }
        } catch {
            print("❌ VideoSaver: Failed to touch wallpaper files: \(error)")
        }
    }
    
    private func runShellCommand(_ command: String, arguments: [String]) async {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = [command] + arguments
        
        do {
            try task.run()
        } catch {
            print("❌ VideoSaver: Failed to run \(command): \(error)")
        }
    }
    
    // MARK: - Helper Methods - odstraněno, nepoužíváme externí video soubory
    
    // MARK: - Configuration Sheet (upraveno)
    
    override var hasConfigureSheet: Bool { true }
    
    override var configureSheet: NSWindow? {
        let alert = NSAlert()
        alert.messageText = "VideoSaver Configuration"
        alert.informativeText = "This screen saver automatically refreshes WallMotion wallpapers when your Mac wakes up. No configuration needed!"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        // Přidej tlačítko pro test refresh
        alert.addButton(withTitle: "Test Refresh")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            refreshWallMotionWallpaper()
        }
        
        return nil
    }
}
