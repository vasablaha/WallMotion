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
    @Published var selectedCategory: VideoCategory = .custom
    
    private let wallpaperPath = "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"
    
    init() {
        print("WallpaperManager: Premium version initialized")
        loadVideoLibrary()
        detectCurrentWallpaper()
    }
    
    func loadVideoLibrary() {
        videoLibrary = [
            // F1 Category
            WallpaperVideo(
                name: "Red Bull RB19 Monaco",
                category: .f1,
                duration: "2:45",
                resolution: "4K",
                thumbnailName: "redbull_monaco_thumb",
                fileName: "redbull_monaco.mov",
                description: "Max Verstappen's Red Bull racing through Monaco streets"
            ),
            WallpaperVideo(
                name: "Ferrari at Monza",
                category: .f1,
                duration: "1:58",
                resolution: "4K",
                thumbnailName: "ferrari_monza_thumb",
                fileName: "ferrari_monza.mov",
                description: "Ferrari SF-23 at the legendary Monza circuit"
            ),
            WallpaperVideo(
                name: "Mercedes W14 Silverstone",
                category: .f1,
                duration: "2:30",
                resolution: "4K",
                thumbnailName: "mercedes_silverstone_thumb",
                fileName: "mercedes_silverstone.mov",
                description: "Mercedes AMG at British Grand Prix"
            ),
            
            // Cars Category
            WallpaperVideo(
                name: "Lamborghini Huracán",
                category: .cars,
                duration: "3:15",
                resolution: "4K",
                thumbnailName: "lambo_huracan_thumb",
                fileName: "lambo_huracan.mov",
                description: "Stunning Lamborghini Huracán on mountain roads"
            ),
            WallpaperVideo(
                name: "BMW M3 Night Drive",
                category: .cars,
                duration: "2:22",
                resolution: "4K",
                thumbnailName: "bmw_m3_night_thumb",
                fileName: "bmw_m3_night.mov",
                description: "BMW M3 cruising through neon-lit city streets"
            ),
            WallpaperVideo(
                name: "JDM Skyline R34",
                category: .cars,
                duration: "1:45",
                resolution: "4K",
                thumbnailName: "skyline_r34_thumb",
                fileName: "skyline_r34.mov",
                description: "Iconic Nissan Skyline R34 GT-R drifting"
            ),
            
            // Nature Category
            WallpaperVideo(
                name: "Alpine Sunrise",
                category: .nature,
                duration: "3:30",
                resolution: "4K",
                thumbnailName: "alpine_sunrise_thumb",
                fileName: "alpine_sunrise.mov",
                description: "Breathtaking sunrise over snow-capped mountains"
            ),
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
                name: "Ocean Waves",
                category: .nature,
                duration: "4:00",
                resolution: "4K",
                thumbnailName: "ocean_waves_thumb",
                fileName: "ocean_waves.mov",
                description: "Mesmerizing ocean waves on tropical beach"
            ),
            
            // Drone Category
            WallpaperVideo(
                name: "Coastal Cliffs Aerial",
                category: .drone,
                duration: "2:45",
                resolution: "4K",
                thumbnailName: "coastal_cliffs_thumb",
                fileName: "coastal_cliffs.mov",
                description: "Dramatic aerial view of rugged coastal cliffs"
            ),
            WallpaperVideo(
                name: "City from Above",
                category: .drone,
                duration: "1:55",
                resolution: "4K",
                thumbnailName: "city_above_thumb",
                fileName: "city_above.mov",
                description: "Urban landscape captured from drone perspective"
            ),
            
            // Anime Category
            WallpaperVideo(
                name: "Ghibli Forest",
                category: .anime,
                duration: "3:20",
                resolution: "4K",
                thumbnailName: "ghibli_forest_thumb",
                fileName: "ghibli_forest.mov",
                description: "Studio Ghibli inspired magical forest animation"
            ),
            WallpaperVideo(
                name: "Cyberpunk Anime City",
                category: .anime,
                duration: "2:10",
                resolution: "4K",
                thumbnailName: "cyberpunk_anime_thumb",
                fileName: "cyberpunk_anime.mov",
                description: "Anime-style cyberpunk cityscape with neon lights"
            ),
            
            // Space Category
            WallpaperVideo(
                name: "Galaxy Spiral",
                category: .space,
                duration: "3:30",
                resolution: "4K",
                thumbnailName: "galaxy_spiral_thumb",
                fileName: "galaxy_spiral.mov",
                description: "Stunning spiral galaxy rotation in deep space"
            ),
            WallpaperVideo(
                name: "Earth from ISS",
                category: .space,
                duration: "2:15",
                resolution: "4K",
                thumbnailName: "earth_iss_thumb",
                fileName: "earth_iss.mov",
                description: "Earth as seen from International Space Station"
            ),
            
            // Cyberpunk Category
            WallpaperVideo(
                name: "Tokyo Neon Night",
                category: .cyberpunk,
                duration: "2:40",
                resolution: "4K",
                thumbnailName: "tokyo_neon_thumb",
                fileName: "tokyo_neon.mov",
                description: "Neon-lit Tokyo streets in Blade Runner style"
            ),
            WallpaperVideo(
                name: "Cyber Rain",
                category: .cyberpunk,
                duration: "1:50",
                resolution: "4K",
                thumbnailName: "cyber_rain_thumb",
                fileName: "cyber_rain.mov",
                description: "Futuristic city with digital rain effects"
            ),
            
            // Gaming Category
            WallpaperVideo(
                name: "Minecraft Timelapse",
                category: .gaming,
                duration: "2:25",
                resolution: "4K",
                thumbnailName: "minecraft_build_thumb",
                fileName: "minecraft_build.mov",
                description: "Epic Minecraft castle build timelapse"
            ),
            WallpaperVideo(
                name: "Cyberpunk 2077 City",
                category: .gaming,
                duration: "3:05",
                resolution: "4K",
                thumbnailName: "cp2077_city_thumb",
                fileName: "cp2077_city.mov",
                description: "Night City inspired futuristic metropolis"
            ),
            
            // Lo-fi Category
            WallpaperVideo(
                name: "Cozy Study Room",
                category: .lofi,
                duration: "4:30",
                resolution: "4K",
                thumbnailName: "cozy_study_thumb",
                fileName: "cozy_study.mov",
                description: "Warm, cozy study room with gentle lighting"
            ),
            WallpaperVideo(
                name: "Rain on Window",
                category: .lofi,
                duration: "5:00",
                resolution: "4K",
                thumbnailName: "rain_window_thumb",
                fileName: "rain_window.mov",
                description: "Relaxing rain drops on coffee shop window"
            ),
            
            // Animals Category
            WallpaperVideo(
                name: "Minimalist Cat",
                category: .animals,
                duration: "1:30",
                resolution: "4K",
                thumbnailName: "minimal_cat_thumb",
                fileName: "minimal_cat.mov",
                description: "Stylized cat animation in minimal design"
            ),
            WallpaperVideo(
                name: "Forest Fox",
                category: .animals,
                duration: "2:15",
                resolution: "4K",
                thumbnailName: "forest_fox_thumb",
                fileName: "forest_fox.mov",
                description: "Cute fox in magical forest setting"
            ),
            
            // Aesthetic Category
            WallpaperVideo(
                name: "Dark Academia Library",
                category: .aesthetics,
                duration: "3:45",
                resolution: "4K",
                thumbnailName: "dark_academia_thumb",
                fileName: "dark_academia.mov",
                description: "Atmospheric old library with warm lighting"
            ),
            WallpaperVideo(
                name: "Vaporwave Sunset",
                category: .aesthetics,
                duration: "2:35",
                resolution: "4K",
                thumbnailName: "vaporwave_thumb",
                fileName: "vaporwave.mov",
                description: "Retro 80s synthwave aesthetic sunset"
            ),
            
            // Seasonal Category
            WallpaperVideo(
                name: "Autumn Leaves Fall",
                category: .seasonal,
                duration: "3:00",
                resolution: "4K",
                thumbnailName: "autumn_leaves_thumb",
                fileName: "autumn_leaves.mov",
                description: "Golden autumn leaves gently falling"
            ),
            WallpaperVideo(
                name: "Winter Snowfall",
                category: .seasonal,
                duration: "2:50",
                resolution: "4K",
                thumbnailName: "winter_snow_thumb",
                fileName: "winter_snow.mov",
                description: "Peaceful snowfall in winter forest"
            )
        ]
        
        print("Loaded \(videoLibrary.count) videos across \(VideoCategory.allCases.count) categories")
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
