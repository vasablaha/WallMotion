import Foundation
import Combine
import AppKit
import Security

class WallpaperManager: ObservableObject {
    // MARK: - Singleton
    static let shared = WallpaperManager()
    
    @Published var availableWallpapers: [String] = []
    @Published var detectedWallpaper: String = ""
    @Published var selectedCategory: VideoCategory = .custom

    private let wallpaperPath = "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"
    
    // MARK: - Authorization
    private var authorizationRef: AuthorizationRef?

    // MARK: - Private Init (Singleton)
    private init() {
        print("WallpaperManager: Premium version initialized (singleton)")
        detectCurrentWallpaper()
        registerForLockNotifications()
    }
    
    deinit {
        if let authRef = authorizationRef {
            AuthorizationFree(authRef, AuthorizationFlags())
        }
    }

    // MARK: - Notifications
    private func registerForLockNotifications() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(self,
                           selector: #selector(screenLocked),
                           name: NSNotification.Name("com.apple.screenIsLocked"),
                           object: nil)
        center.addObserver(self,
                           selector: #selector(screenUnlocked),
                           name: NSNotification.Name("com.apple.screenIsUnlocked"),
                           object: nil)
    }

    @objc private func screenLocked(_ notification: Notification) {
        print("Screen locked - pausing wallpaper agent")
        _ = runShell("/usr/bin/killall", ["WallpaperAgent"])
    }

    @objc private func screenUnlocked(_ notification: Notification) {
        print("Screen unlocked - restarting wallpaper agent")
        reloadWallpaperAgent()
    }

    private func reloadWallpaperAgent() {
        guard !detectedWallpaper.isEmpty else { return }
        let targetPath = "\(wallpaperPath)/\(detectedWallpaper).mov"
        print("Reloading wallpaper agent for file: \(targetPath)")
        _ = runShell("/usr/bin/touch", [targetPath])
        _ = runShell("/usr/bin/killall", ["WallpaperAgent"])
    }

    // MARK: - Detecting
    func detectCurrentWallpaper() {
        print("Detecting currently set wallpaper...")
        print("Scanning: \(wallpaperPath)")

        guard FileManager.default.fileExists(atPath: wallpaperPath) else {
            print("Wallpaper folder not found: \(wallpaperPath)")
            detectedWallpaper = "No wallpaper detected - please set one first"
            availableWallpapers = []
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: wallpaperPath)
            let movFiles = files.filter {
                $0.hasSuffix(".mov") && !$0.contains(".backup")
            }

            print("Found \(movFiles.count) .mov files in folder")

            if movFiles.isEmpty {
                detectedWallpaper = "No wallpapers downloaded - set one first"
                availableWallpapers = []
                return
            }

            var newestFile: String = ""
            var newestDate: Date = .distantPast

            for file in movFiles {
                let path = "\(wallpaperPath)/\(file)"
                let attributes = try FileManager.default.attributesOfItem(atPath: path)
                if let modDate = attributes[.modificationDate] as? Date, modDate > newestDate {
                    newestDate = modDate
                    newestFile = file
                }
            }

            if !newestFile.isEmpty {
                let name = newestFile.replacingOccurrences(of: ".mov", with: "")
                detectedWallpaper = name
                availableWallpapers = [name]
                print("Detected current wallpaper: \(name)")
            } else {
                detectedWallpaper = "Detection failed"
                availableWallpapers = []
            }

        } catch {
            print("Error scanning wallpaper folder: \(error.localizedDescription)")
            detectedWallpaper = "Error: \(error.localizedDescription)"
            availableWallpapers = []
        }
    }

    // MARK: - Replacing
    func replaceWallpaper(
        videoURL: URL,
        progressCallback: @escaping (Double, String) -> Void
    ) async {
        print("Starting smart wallpaper replacement...")
        print("Source video: \(videoURL.path)")

        progressCallback(0.1, "Detecting current wallpaper...")
        await MainActor.run { detectCurrentWallpaper() }

        guard !detectedWallpaper.isEmpty,
              !detectedWallpaper.contains("No wallpaper"),
              !detectedWallpaper.contains("Error") else {
            progressCallback(0.0, "No wallpaper detected. Please set a video wallpaper in System Settings first!")
            return
        }

        let targetPath = "\(wallpaperPath)/\(detectedWallpaper).mov"
        print("Target path: \(targetPath)")

        // Backup original with sudo
        progressCallback(0.2, "Creating backup...")
        let backupPath = "\(wallpaperPath)/\(detectedWallpaper).backup.mov"
        let backupSuccess = await createBackupWithSudo(originalPath: targetPath, backupPath: backupPath)
        
        if !backupSuccess {
            progressCallback(0.0, "Failed to create backup. Please enter administrator password when prompted.")
            return
        }

        // Process video
        progressCallback(0.3, "Processing video...")
        let tempProcessedURL = await processVideo(videoURL: videoURL)

        guard let processedURL = tempProcessedURL else {
            progressCallback(0.0, "Video processing failed!")
            return
        }

        // Replace file with sudo
        progressCallback(0.8, "Replacing wallpaper file...")
        let replaceSuccess = await replaceFileWithSudo(processedURL: processedURL, targetPath: targetPath)
        
        if !replaceSuccess {
            progressCallback(0.0, "Failed to replace wallpaper file! Please check administrator password.")
            return
        }

        // Reload system
        progressCallback(0.9, "Refreshing wallpaper system...")
        await reloadWallpaperSystem()

        progressCallback(1.0, "Wallpaper replaced successfully!")
        
        // Update detection
        await MainActor.run { detectCurrentWallpaper() }
    }

    // MARK: - Private Processing Methods (with Sudo)
    
    private func createBackupWithSudo(originalPath: String, backupPath: String) async -> Bool {
        // Check if original file exists
        guard FileManager.default.fileExists(atPath: originalPath) else {
            print("⚠️ Original file doesn't exist, skipping backup")
            return true
        }
        
        // Remove old backup if exists
        if FileManager.default.fileExists(atPath: backupPath) {
            let removeResult = await runSudoCommand("/bin/rm", ["-f", backupPath])
            if !removeResult.success {
                print("⚠️ Failed to remove old backup: \(removeResult.output)")
            }
        }
        
        // Create backup using sudo cp
        let copyResult = await runSudoCommand("/bin/cp", [originalPath, backupPath])
        
        if copyResult.success {
            print("✅ Backup created at: \(backupPath)")
            return true
        } else {
            print("❌ Backup creation failed: \(copyResult.output)")
            return false
        }
    }

    private func processVideo(videoURL: URL) async -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("processed_wallpaper.mov")
        
        // Simple copy for now - could add ffmpeg processing here
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            
            // Ensure we're working with file URLs
            let sourceURL = videoURL.standardizedFileURL
            let destinationURL = tempURL.standardizedFileURL
            
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("✅ Video processed: \(destinationURL.path)")
            return destinationURL
        } catch {
            print("❌ Video processing failed: \(error)")
            return nil
        }
    }

    private func replaceFileWithSudo(processedURL: URL, targetPath: String) async -> Bool {
        // First copy processed video to a temporary location accessible to sudo
        let tempPath = "/tmp/wallmotion_temp.mov"
        
        do {
            // Remove temp file if exists
            if FileManager.default.fileExists(atPath: tempPath) {
                try FileManager.default.removeItem(atPath: tempPath)
            }
            
            // Copy processed video to temp location
            try FileManager.default.copyItem(at: processedURL, to: URL(fileURLWithPath: tempPath))
        } catch {
            print("❌ Failed to prepare temp file: \(error)")
            return false
        }
        
        // Remove original wallpaper file with sudo
        let removeResult = await runSudoCommand("/bin/rm", ["-f", targetPath])
        if !removeResult.success {
            print("❌ Failed to remove original file: \(removeResult.output)")
            return false
        }
        
        // Copy new file with sudo
        let copyResult = await runSudoCommand("/bin/cp", [tempPath, targetPath])
        
        // Cleanup temp file
        do {
            if FileManager.default.fileExists(atPath: tempPath) {
                try FileManager.default.removeItem(atPath: tempPath)
            }
        } catch {
            print("⚠️ Failed to cleanup temp file: \(error)")
        }
        
        if copyResult.success {
            print("✅ File replaced at: \(targetPath)")
            return true
        } else {
            print("❌ File replacement failed: \(copyResult.output)")
            return false
        }
    }

    // MARK: - Sudo Command Runner
    
    private func runSudoCommand(_ command: String, _ arguments: [String]) async -> (success: Bool, output: String) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                task.arguments = [command] + arguments
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    let success = task.terminationStatus == 0
                    
                    continuation.resume(returning: (success, output))
                } catch {
                    continuation.resume(returning: (false, "Failed to run sudo command: \(error)"))
                }
            }
        }
    }

    private func reloadWallpaperSystem() async {
        // Touch the file to trigger system reload using sudo
        let touchResult = await runSudoCommand("/usr/bin/touch", ["\(wallpaperPath)/\(detectedWallpaper).mov"])
        if touchResult.success {
            print("✅ Touched wallpaper file")
        } else {
            print("⚠️ Failed to touch file: \(touchResult.output)")
        }
        
        // Kill and restart wallpaper agent
        let killResult = await runSudoCommand("/usr/bin/killall", ["WallpaperAgent"])
        if killResult.success {
            print("✅ Wallpaper agent restarted")
        } else {
            print("⚠️ Failed to kill WallpaperAgent: \(killResult.output)")
        }
        
        // Small delay for system to process
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        print("✅ Wallpaper system reloaded")
    }

    // MARK: - Shell Helper (Updated with proper paths)
    private func runShell(_ command: String, _ arguments: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: command)
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("Shell command failed: \(error)")
            return ""
        }
    }
}
