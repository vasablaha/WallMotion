//
//  ExecutableManager.swift
//  WallMotion
//
//  Centralized path resolution for embedded CLI tools
//

import Foundation

class ExecutableManager {
    
    // MARK: - Singleton
    static let shared = ExecutableManager()
    private init() {}
    
    // MARK: - Development vs Distribution Detection
    
    private var isDevelopment: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Public API
    
    /// Gets the path to an executable, checking bundle first, then system paths for development
    func getExecutablePath(for tool: String) throws -> URL {
        // Always try bundle first (works in both dev and distribution)
        if let bundleURL = getBundleExecutable(tool) {
            return bundleURL
        }
        
        // IMPORTANT: Also fallback to system paths in release for .dmg distribution
        // This ensures the app works even if bundled executables fail due to signing/quarantine
        print("⚠️ Bundle executable not found, trying system paths...")
        if let systemURL = getSystemExecutable(tool) {
            return systemURL
        }
        
        throw ExecutableError.notFound(tool)
    }
    
    /// Convenience method that returns String path
    func getExecutablePathString(for tool: String) throws -> String {
        return try getExecutablePath(for: tool).path
    }
    
    /// Check if executable exists and is available
    func isExecutableAvailable(_ tool: String) -> Bool {
        do {
            let url = try getExecutablePath(for: tool)
            return FileManager.default.isExecutableFile(atPath: url.path)
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    /// Look for executable in app bundle Resources
    private func getBundleExecutable(_ tool: String) -> URL? {
        print("🔍 Looking for \(tool) in app bundle...")
        print("🔍 Bundle path: \(Bundle.main.bundlePath)")
        print("🔍 Resource path: \(Bundle.main.resourcePath ?? "nil")")
        
        // Method 1: Try Bundle.main.url(forResource:)
        if let bundleURL = Bundle.main.url(forResource: tool, withExtension: nil) {
            print("✅ Found \(tool) via Bundle.main.url: \(bundleURL.path)")
            
            // Verify it's executable
            if FileManager.default.isExecutableFile(atPath: bundleURL.path) {
                print("✅ \(tool) is executable")
                return bundleURL
            } else {
                print("⚠️ \(tool) found but not executable: \(bundleURL.path)")
            }
        } else {
            print("⚠️ \(tool) not found via Bundle.main.url")
        }
        
        // Method 2: Try direct path in Resources
        if let resourcePath = Bundle.main.resourcePath {
            let directPath = "\(resourcePath)/\(tool)"
            print("🔍 Trying direct path: \(directPath)")
            
            if FileManager.default.fileExists(atPath: directPath) {
                print("✅ Found \(tool) at direct path")
                
                if FileManager.default.isExecutableFile(atPath: directPath) {
                    print("✅ \(tool) is executable at direct path")
                    return URL(fileURLWithPath: directPath)
                } else {
                    print("⚠️ \(tool) found but not executable at direct path")
                }
            } else {
                print("⚠️ \(tool) not found at direct path")
            }
        }
        
        // Method 3: List all files in Resources for debugging
        if let resourcePath = Bundle.main.resourcePath {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("📁 Files in Resources: \(files)")
            } catch {
                print("❌ Error listing Resources: \(error)")
            }
        }
        
        print("❌ \(tool) not found in app bundle")
        return nil
    }
    
    /// Look for executable in common system paths (development only)
    private func getSystemExecutable(_ tool: String) -> URL? {
        print("🔍 Looking for \(tool) in system paths...")
        
        let systemPaths = [
            "/opt/homebrew/bin/\(tool)",
            "/usr/local/bin/\(tool)",
            "/usr/bin/\(tool)",
            "/bin/\(tool)"
        ]
        
        for path in systemPaths {
            print("🔍 Checking system path: \(path)")
            if FileManager.default.isExecutableFile(atPath: path) {
                print("✅ Found \(tool) in system: \(path)")
                return URL(fileURLWithPath: path)
            }
        }
        
        print("⚠️ \(tool) not found in system paths")
        return nil
    }
}

// MARK: - Error Types

enum ExecutableError: LocalizedError {
    case notFound(String)
    case notExecutable(String)
    case bundleError(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound(let tool):
            return "\(tool) executable not found in bundle or system paths"
        case .notExecutable(let tool):
            return "\(tool) found but not executable"
        case .bundleError(let description):
            return "Bundle error: \(description)"
        }
    }
}

// MARK: - Convenience Extensions

extension ExecutableManager {
    
    /// Common tools shortcuts
    var ytdlpPath: URL? {
        try? getExecutablePath(for: "yt-dlp")
    }
    
    var ffmpegPath: URL? {
        try? getExecutablePath(for: "ffmpeg")
    }
    
    var ffprobePath: URL? {
        try? getExecutablePath(for: "ffprobe")
    }
    
    var videoSaverPath: URL? {
        try? getExecutablePath(for: "VideoSaver")
    }
    
    /// Dependency status check
    func checkAllDependencies() -> (ytdlp: Bool, ffmpeg: Bool, ffprobe: Bool, videoSaver: Bool) {
        return (
            ytdlp: isExecutableAvailable("yt-dlp"),
            ffmpeg: isExecutableAvailable("ffmpeg"),
            ffprobe: isExecutableAvailable("ffprobe"),
            videoSaver: isExecutableAvailable("VideoSaver")
        )
    }
}
