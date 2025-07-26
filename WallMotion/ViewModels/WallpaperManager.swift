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
    }
    
    deinit {
        if let authRef = authorizationRef {
            AuthorizationFree(authRef, AuthorizationFlags())
        }
    }

    func detectCurrentWallpaper() {
        print("🔍 Checking for live wallpaper...")
        print("📁 Scanning: \(wallpaperPath)")

        guard FileManager.default.fileExists(atPath: wallpaperPath) else {
            print("❌ Wallpaper folder not found: \(wallpaperPath)")
            detectedWallpaper = "No wallpaper detected - please set live wallpaper first"
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
                detectedWallpaper = "No wallpapers found - please set live wallpaper first"
                availableWallpapers = []
                return
            }

            // ✅ OPRAVENO: Prostě použij první .mov soubor (bez kontroly názvu)
            let firstWallpaper = movFiles[0]
            let wallpaperName = firstWallpaper.replacingOccurrences(of: ".mov", with: "")
            
            detectedWallpaper = wallpaperName
            availableWallpapers = [wallpaperName]
            
            print("✅ Found wallpaper file: \(wallpaperName)")
            
            // ✅ ŽÁDNÁ KONTROLA NÁZVU - soubory mají random UUID názvy!
            print("🎬 Live wallpaper detected - VideoSaver agent ready")

        } catch {
            print("❌ Error scanning wallpaper folder: \(error.localizedDescription)")
            detectedWallpaper = "Error: \(error.localizedDescription)"
            availableWallpapers = []
        }
    }
    
    
    // ✅ NOVÁ METODA: Detekce skutečné aktivní tapety
    private func detectActualActiveWallpaper() -> String? {
        guard let screen = NSScreen.main else {
            print("❌ No main screen found")
            return nil
        }
        
        do {
            // Získej URL aktivní tapety
            guard let currentWallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen) else {
                print("❌ Cannot get current wallpaper URL")
                return nil
            }
            
            let currentPath = currentWallpaperURL.path
            print("🔍 Current wallpaper path: \(currentPath)")
            
            // Zkontroluj, jestli to je soubor z našeho wallpaper adresáře
            if currentPath.contains(wallpaperPath) {
                let fileName = currentWallpaperURL.lastPathComponent
                let wallpaperName = fileName.replacingOccurrences(of: ".mov", with: "")
                
                // Ověř, že soubor skutečně existuje
                if FileManager.default.fileExists(atPath: currentPath) {
                    print("✅ Found matching wallpaper: \(wallpaperName)")
                    return wallpaperName
                }
            }
            
            // Pokud přímá cesta nesedí, zkus najít podobný soubor
            print("🔍 Wallpaper not directly in our folder, searching for matches...")
            return findMatchingWallpaperFile(for: currentWallpaperURL)
            
        } catch {
            print("❌ Error detecting actual wallpaper: \(error)")
            return nil
        }
    }
    // ✅ NOVÁ METODA: Najdi odpovídající soubor v wallpaper složce
    private func findMatchingWallpaperFile(for wallpaperURL: URL) -> String? {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: wallpaperPath)
            let movFiles = files.filter { $0.hasSuffix(".mov") && !$0.contains(".backup") }
            
            let currentFileName = wallpaperURL.lastPathComponent
            let currentBaseName = wallpaperURL.deletingPathExtension().lastPathComponent
            
            print("🔍 Looking for match to: \(currentFileName) or \(currentBaseName)")
            
            // Zkus najít přesnou shodu
            for file in movFiles {
                let baseName = (file as NSString).deletingPathExtension
                
                // Přesná shoda názvu
                if baseName.lowercased() == currentBaseName.lowercased() {
                    print("✅ Found exact match: \(baseName)")
                    return baseName
                }
                
                // Podobnost (obsahuje klíčová slova)
                if areWallpapersSimilar(baseName, currentBaseName) {
                    print("✅ Found similar match: \(baseName)")
                    return baseName
                }
            }
            
            print("⚠️ No matching wallpaper found")
            return nil
            
        } catch {
            print("❌ Error scanning wallpaper files: \(error)")
            return nil
        }
    }
    
    // ✅ NOVÁ METODA: Porovnání podobnosti tapet
    private func areWallpapersSimilar(_ name1: String, _ name2: String) -> Bool {
        let normalized1 = name1.lowercased().replacingOccurrences(of: " ", with: "")
        let normalized2 = name2.lowercased().replacingOccurrences(of: " ", with: "")
        
        // Klíčová slova pro rozpoznání konkrétních tapet
        let wallpaperKeywords: [String: [String]] = [
            "sonoma": ["sonoma", "horizon", "sonomsky"],
            "sequoia": ["sequoia", "sekvoj", "sunrise", "vychod"],
            "ventura": ["ventura"],
            "monterey": ["monterey"],
            "bigsur": ["bigsur", "big", "sur"],
            "catalina": ["catalina"],
            "mojave": ["mojave"]
        ]
        
        // Najdi kategorie pro oba názvy
        var category1: String?
        var category2: String?
        
        for (category, keywords) in wallpaperKeywords {
            if keywords.contains(where: { normalized1.contains($0) }) {
                category1 = category
            }
            if keywords.contains(where: { normalized2.contains($0) }) {
                category2 = category
            }
        }
        
        // Pokud oba patří do stejné kategorie, jsou podobné
        if let cat1 = category1, let cat2 = category2, cat1 == cat2 {
            return true
        }
        
        return false
    }

    // 🔄 FALLBACK METODA: Použij původní logiku jako zálohu
    private func fallbackDetection() {
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

            // Místo nejnovějšího souboru, nech uživatele vybrat nebo použij všechny
            availableWallpapers = movFiles.map { $0.replacingOccurrences(of: ".mov", with: "") }
            
            if availableWallpapers.count == 1 {
                detectedWallpaper = availableWallpapers[0]
                print("📝 Single wallpaper found: \(detectedWallpaper)")
            } else {
                // Pokud je více tapet, zkus najít "sonoma" nebo "horizon"
                let preferredNames = ["sonoma", "horizon", "sonomsky"]
                
                for preferred in preferredNames {
                    if let found = availableWallpapers.first(where: {
                        $0.lowercased().contains(preferred)
                    }) {
                        detectedWallpaper = found
                        print("📝 Preferred wallpaper found: \(detectedWallpaper)")
                        return
                    }
                }
                
                // Jinak použij první dostupný
                detectedWallpaper = availableWallpapers[0]
                print("📝 Multiple wallpapers found, using first: \(detectedWallpaper)")
            }

        } catch {
            print("❌ Error scanning wallpaper folder: \(error.localizedDescription)")
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
        
        let script = """
        do shell script "
        if [ -f '\(backupPath)' ]; then
            rm -f '\(backupPath)'
        fi
        cp '\(originalPath)' '\(backupPath)'
        " with administrator privileges
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let appleScript = NSAppleScript(source: script)
                var error: NSDictionary?
                let _ = appleScript?.executeAndReturnError(&error)
                
                if let error = error {
                    print("❌ Backup creation failed: \(error)")
                    continuation.resume(returning: false)
                } else {
                    print("✅ Backup created at: \(backupPath)")
                    continuation.resume(returning: true)
                }
            }
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
        
        let script = """
        do shell script "
        rm -f '\(targetPath)'
        cp '\(tempPath)' '\(targetPath)'
        rm -f '\(tempPath)'
        " with administrator privileges
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let appleScript = NSAppleScript(source: script)
                var error: NSDictionary?
                let _ = appleScript?.executeAndReturnError(&error)
                
                if let error = error {
                    print("❌ File replacement failed: \(error)")
                    continuation.resume(returning: false)
                } else {
                    print("✅ File replaced at: \(targetPath)")
                    continuation.resume(returning: true)
                }
            }
        }
    }


    private func reloadWallpaperSystem() async {
        let script = """
        do shell script "
        touch '\(wallpaperPath)/\(detectedWallpaper).mov'
        killall WallpaperAgent 2>/dev/null || true
        " with administrator privileges
        """
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let appleScript = NSAppleScript(source: script)
                var error: NSDictionary?
                let _ = appleScript?.executeAndReturnError(&error)
                
                if let error = error {
                    print("⚠️ Failed to reload wallpaper system: \(error)")
                } else {
                    print("✅ Wallpaper system reloaded")
                }
                
                continuation.resume()
            }
        }
        
        // Small delay for system to process
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
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
