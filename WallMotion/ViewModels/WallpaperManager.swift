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
    @Published var videoLibrary: [WallpaperVideo] = []
    @Published var selectedCategory: VideoCategory = .custom // Changed to custom as default since categories are hidden
    
    private let wallpaperPath = "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"
    
    init() {
        print("WallpaperManager: Premium version initialized")
        loadVideoLibrary()
        detectCurrentWallpaper()
    }
    
    func loadVideoLibrary() {
        videoLibrary = [
            // Nature Category
            WallpaperVideo(
                name: "Forest Rain",
                category: .nature,
                duration: "2:30",
                resolution: "4K",
                thumbnailName: "forest_rain_thumb",
                fileName: "forest_rain.mov",
                description: "Gentle rain falling through green forest canopy"
            ),
            WallpaperVideo(
                name: "Mountain Mist",
                category: .nature,
                duration: "1:45",
                resolution: "4K",
                thumbnailName: "mountain_mist_thumb",
                fileName: "mountain_mist.mov",
                description: "Misty clouds rolling over mountain peaks"
            ),
            WallpaperVideo(
                name: "Autumn Leaves",
                category: .nature,
                duration: "3:00",
                resolution: "4K",
                thumbnailName: "autumn_leaves_thumb",
                fileName: "autumn_leaves.mov",
                description: "Golden leaves gently falling in autumn breeze"
            ),
            
            // Ocean Category
            WallpaperVideo(
                name: "Deep Blue",
                category: .ocean,
                duration: "2:15",
                resolution: "4K",
                thumbnailName: "deep_blue_thumb",
                fileName: "deep_blue.mov",
                description: "Mesmerizing deep ocean waves"
            ),
            WallpaperVideo(
                name: "Coral Garden",
                category: .ocean,
                duration: "4:00",
                resolution: "4K",
                thumbnailName: "coral_garden_thumb",
                fileName: "coral_garden.mov",
                description: "Vibrant coral reef with tropical fish"
            ),
            
            // Abstract Category
            WallpaperVideo(
                name: "Fluid Motion",
                category: .abstract,
                duration: "1:30",
                resolution: "4K",
                thumbnailName: "fluid_motion_thumb",
                fileName: "fluid_motion.mov",
                description: "Smooth flowing abstract patterns"
            ),
            WallpaperVideo(
                name: "Neon Dreams",
                category: .abstract,
                duration: "2:45",
                resolution: "4K",
                thumbnailName: "neon_dreams_thumb",
                fileName: "neon_dreams.mov",
                description: "Colorful neon lights and geometric shapes"
            ),
            
            // Space Category
            WallpaperVideo(
                name: "Galaxy Spiral",
                category: .space,
                duration: "3:30",
                resolution: "4K",
                thumbnailName: "galaxy_spiral_thumb",
                fileName: "galaxy_spiral.mov",
                description: "Stunning spiral galaxy rotation"
            ),
            WallpaperVideo(
                name: "Nebula",
                category: .space,
                duration: "2:00",
                resolution: "4K",
                thumbnailName: "nebula_thumb",
                fileName: "nebula.mov",
                description: "Colorful cosmic nebula clouds"
            ),
            
            // Minimal Category
            WallpaperVideo(
                name: "Clean Waves",
                category: .minimal,
                duration: "1:20",
                resolution: "4K",
                thumbnailName: "clean_waves_thumb",
                fileName: "clean_waves.mov",
                description: "Simple, elegant wave animation"
            )
        ]
        
        print("Loaded \(videoLibrary.count) videos in library")
    }
    
    var filteredVideos: [WallpaperVideo] {
        if selectedCategory == .custom {
            return []
        }
        return videoLibrary.filter { $0.category == selectedCategory }
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
