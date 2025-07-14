//
//  WallpaperManager.swift
//  WallMotion
//
//  Created by Václav Blaha on 13.07.2025.
//

import Foundation
import Combine

class WallpaperManager: ObservableObject {
    @Published var availableWallpapers: [String] = []
    @Published var detectedWallpaper: String = ""
    @Published var selectedCategory: VideoCategory = .custom // This line might need adjustment if VideoCategory is solely for the video library.

    private let wallpaperPath = "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"

    init() {
        print("WallpaperManager: Premium version initialized")
        // loadVideoLibrary() // Removed as videoLibrary is no longer present
        detectCurrentWallpaper()
    }

    // func loadVideoLibrary() { // Entire function removed
    //     videoLibrary = [
    //         // ... (all WallpaperVideo entries removed) ...
    //     ]
    //     print("Loaded \(videoLibrary.count) videos across \(VideoCategory.allCases.count) categories")
    // }

    var filteredVideos: [WallpaperVideo] { // This computed property will need to be removed or significantly altered
        if selectedCategory == .custom {
            return []
        }
        return [] // No videoLibrary to filter, so always return empty
        // return videoLibrary.filter { $0.category == selectedCategory } // Original line removed
    }

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
            let movFiles = files.filter { $0.hasSuffix(".mov") && !$0.contains(".backup") }

            print("Found \(movFiles.count) .mov files in folder")

            if movFiles.isEmpty {
                print("No .mov files found")
                detectedWallpaper = "No wallpapers downloaded - set one first"
                availableWallpapers = []
                return
            }

            var newestFile: String = ""
            var newestDate: Date = Date.distantPast

            for file in movFiles {
                let filePath = "\(wallpaperPath)/\(file)"
                let attributes = try FileManager.default.attributesOfItem(atPath: filePath)

                if let modDate = attributes[.modificationDate] as? Date {
                    if modDate > newestDate {
                        newestDate = modDate
                        newestFile = file
                    }
                }
            }

            if !newestFile.isEmpty {
                let wallpaperName = newestFile.replacingOccurrences(of: ".mov", with: "")
                detectedWallpaper = wallpaperName
                availableWallpapers = [wallpaperName]
                print("Detected current wallpaper: \(wallpaperName)")
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

    func replaceWallpaper(
        videoURL: URL,
        progressCallback: @escaping (Double, String) -> Void
    ) async {

        print("Starting smart wallpaper replacement...")
        print("Source video: \(videoURL.path)")

        progressCallback(0.1, "Detecting current wallpaper...")

        await MainActor.run {
            detectCurrentWallpaper()
        }

        guard !detectedWallpaper.isEmpty && !detectedWallpaper.contains("No wallpaper") && !detectedWallpaper.contains("Error") else {
            progressCallback(0.0, "No wallpaper detected. Please set a video wallpaper in System Settings first!")
            return
        }

        let targetFileName = "\(detectedWallpaper).mov"
        let targetPath = "\(wallpaperPath)/\(targetFileName)"

        progressCallback(0.2, "Preparing video...")

        let tempDir = FileManager.default.temporaryDirectory
        let tempVideoPath = tempDir.appendingPathComponent("wallpaper_temp.mov").path
        let backupPath = "\(targetPath).backup.\(Int(Date().timeIntervalSince1970))"

        do {
            try FileManager.default.copyItem(atPath: videoURL.path, toPath: tempVideoPath)
            print("Video copied to temp location")
        } catch {
            print("Failed to copy to temp: \(error)")
            progressCallback(0.0, "Failed to prepare video")
            return
        }

        progressCallback(0.4, "Requesting admin access (ONE TIME ONLY)...")

        guard await executeAllCommands(tempVideoPath: tempVideoPath, targetPath: targetPath, backupPath: backupPath, progressCallback: progressCallback) else {
            try? FileManager.default.removeItem(atPath: tempVideoPath)
            progressCallback(0.0, "Installation failed")
            return
        }

        try? FileManager.default.removeItem(atPath: tempVideoPath)
        progressCallback(1.0, "Wallpaper replaced! Check System Settings!")
        print("Replacement completed successfully!")
    }

    private func executeAllCommands(tempVideoPath: String, targetPath: String, backupPath: String, progressCallback: @escaping (Double, String) -> Void) async -> Bool {
        print("Requesting admin privileges for complete cleanup operation...")

        await MainActor.run {
            progressCallback(0.5, "Cleaning and installing wallpaper...")
        }

        let batchScript = """
        do shell script "
        cp '\(targetPath)' '\(backupPath)'
        find '\(wallpaperPath)' -name '*.mov' -type f -delete
        find '\(wallpaperPath)' -name '*.backup.*' -type f -delete
        cp '\(tempVideoPath)' '\(targetPath)'
        killall WallpaperAgent 2>/dev/null || true
        " with administrator privileges
        """

        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let appleScript = NSAppleScript(source: batchScript)
                var error: NSDictionary?
                let result = appleScript?.executeAndReturnError(&error)

                if let error = error {
                    print("Batch operation failed: \(error)")
                    continuation.resume(returning: false)
                } else {
                    print("Complete cleanup successful! All old files removed.")
                    continuation.resume(returning: true)
                }
            }
        }

        if success {
            await MainActor.run {
                progressCallback(0.9, "Refreshing system...")
            }
        }

        return success
    }
}
