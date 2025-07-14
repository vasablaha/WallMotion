import Foundation
import Combine

class WallpaperManager: ObservableObject {
    @Published var availableWallpapers: [String] = []
    @Published var detectedWallpaper: String = ""
    @Published var selectedCategory: VideoCategory = .custom

    private let wallpaperPath = "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"

    // MARK: - Init

    init() {
        print("WallpaperManager: Premium version initialized")
        detectCurrentWallpaper()
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
            let movFiles = files.filter { $0.hasSuffix(".mov") && !$0.contains(".backup") }

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

        await MainActor.run {
            detectCurrentWallpaper()
        }

        guard !detectedWallpaper.isEmpty,
              !detectedWallpaper.contains("No wallpaper"),
              !detectedWallpaper.contains("Error") else {
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

        // ✅ FIX: Touch + restart WallpaperAgent (macOS reloads wallpaper)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            let touchResult = self.runShell("touch", [targetPath])
            print("Touched new wallpaper file: \(touchResult)")

            let killResult = self.runShell("killall", ["WallpaperAgent"])
            print("WallpaperAgent killed: \(killResult)")
        }
    }

    // MARK: - Shell execution helper

    func runShell(_ command: String, _ arguments: [String]) -> String {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = [command] + arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
        } catch {
            return "Failed to run \(command): \(error)"
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - AppleScript batch (beze změny)

    private func executeAllCommands(tempVideoPath: String, targetPath: String, backupPath: String, progressCallback: @escaping (Double, String) -> Void) async -> Bool {
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
                let _ = appleScript?.executeAndReturnError(&error)

                if let error = error {
                    print("Batch operation failed: \(error)")
                    continuation.resume(returning: false)
                } else {
                    print("Complete cleanup successful! All old files removed.")
                    continuation.resume(returning: true)
                }
            }
        }

        return success
    }
}
