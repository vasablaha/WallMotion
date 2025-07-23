//
//  DependenciesManager.swift
//  WallMotion - Simplified Bundle-Only Version
//
//  Manages only bundled executables (yt-dlp, ffmpeg, ffprobe)
//

import Foundation
import SwiftUI

@MainActor
class DependenciesManager: ObservableObject {
    // MARK: - Singleton
    static let shared = DependenciesManager()
    private init() {} // Prevent multiple instances
    
    @Published var isInitializing = false
    @Published var statusMessage = ""
    
    // MARK: - Initialization tracking
    private var hasInitialized = false
    
    // MARK: - Bundle-only dependency status
    struct DependencyStatus {
        let ytdlp: Bool
        let ffmpeg: Bool
        let ffprobe: Bool
        
        var allAvailable: Bool {
            return ytdlp && ffmpeg && ffprobe
        }
        
        var missing: [String] {
            var missing: [String] = []
            if !ytdlp { missing.append("yt-dlp") }
            if !ffmpeg { missing.append("ffmpeg") }
            if !ffprobe { missing.append("ffprobe") }
            return missing
        }
    }
    
    // MARK: - Configuration
    private struct BundleConfig {
        static let supportedTools = ["yt-dlp", "ffmpeg", "ffprobe"]
        static let bundleSubpaths = ["", "/Executables", "/bin", "/tools"]
    }
    
    // MARK: - Public API
    
    /// Check status of bundled dependencies (read-only, no fixes applied)
    func checkDependencies() -> DependencyStatus {
        print("🔍 Checking bundled dependencies...")
        
        let ytdlp = isExecutableAvailable("yt-dlp")
        let ffmpeg = isExecutableAvailable("ffmpeg")
        let ffprobe = isExecutableAvailable("ffprobe")
        
        let status = DependencyStatus(
            ytdlp: ytdlp,
            ffmpeg: ffmpeg,
            ffprobe: ffprobe
        )
        
        print("📊 Bundle dependency status:")
        print("   yt-dlp: \(ytdlp ? "✅" : "❌")")
        print("   ffmpeg: \(ffmpeg ? "✅" : "❌")")
        print("   ffprobe: \(ffprobe ? "✅" : "❌")")
        
        return status
    }
    
    /// Find path to bundled executable
    func findExecutablePath(for tool: String) -> String? {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("❌ No bundle resource path")
            return nil
        }
        
        // Check all possible bundle locations
        let candidatePaths = BundleConfig.bundleSubpaths.compactMap { subpath in
            let fullPath = resourcePath + subpath + "/\(tool)"
            return FileManager.default.fileExists(atPath: fullPath) ? fullPath : nil
        }
        
        if let path = candidatePaths.first {
            print("✅ Found bundled \(tool) at: \(path)")
            return path
        }
        
        print("❌ Bundled \(tool) not found")
        return nil
    }
    
    /// Check if executable is available and working
    func isExecutableAvailable(_ tool: String) -> Bool {
        guard let path = findExecutablePath(for: tool) else { return false }
        
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: path)
        let executable = fileManager.isExecutableFile(atPath: path)
        
        print("🔧 \(tool): exists=\(exists), executable=\(executable)")
        
        return exists && executable
    }
    
    /// Initialize bundled executables (fix quarantine, permissions) - runs only once
    func initializeBundledExecutables() async {
        // Prevent multiple initialization runs
        guard !hasInitialized else {
            print("⏭️ Bundled tools already initialized, skipping...")
            return
        }
        
        await MainActor.run {
            isInitializing = true
            statusMessage = "Initializing bundled tools..."
            hasInitialized = true
        }
        
        print("🚀 Initializing bundled executables (first time)...")
        await fixBundledExecutables()
        
        await MainActor.run {
            isInitializing = false
            statusMessage = "Bundled tools ready"
        }
        
        // Trigger UI refresh
        objectWillChange.send()
    }
    
    // MARK: - Bundle Management
    
    /// Fix quarantine and permissions for all bundled executables
    private func fixBundledExecutables() async {
        print("🔧 Fixing bundled executables...")
        
        for tool in BundleConfig.supportedTools {
            if let path = findExecutablePath(for: tool) {
                _ = await QuarantineManager.removeQuarantine(from: path)
                _ = await QuarantineManager.makeExecutable(path)
            }
        }
        
        print("✅ Bundled executables fixed")
    }
    
    // MARK: - Validation & Testing
    
    /// Test if executable actually works by running version command
    func testExecutable(_ tool: String) async -> Bool {
        guard let path = findExecutablePath(for: tool) else { return false }
        
        let versionArgs: [String]
        switch tool {
        case "yt-dlp":
            versionArgs = ["--version"]
        case "ffmpeg", "ffprobe":
            versionArgs = ["-version"]
        default:
            versionArgs = ["--version"]
        }
        
        let (success, output) = await ShellCommandExecutor.run(path, arguments: versionArgs)
        
        if success {
            print("✅ \(tool) test passed: \(output.prefix(50))...")
        } else {
            print("❌ \(tool) test failed: \(output.prefix(100))...")
        }
        
        return success && !output.contains("ERROR") && !output.contains("Permission denied")
    }
    
    /// Generate diagnostic report for bundled tools
    func generateDiagnosticReport() -> String {
        var report = "🔍 WallMotion Bundled Dependencies Report\n"
        report += "=" + String(repeating: "=", count: 45) + "\n\n"
        
        // Bundle info
        let bundlePath = Bundle.main.bundlePath
        if let resourcePath = Bundle.main.resourcePath {
            report += "📦 Bundle Information:\n"
            report += "• Bundle path: \(bundlePath)\n"
            report += "• Resource path: \(resourcePath)\n\n"
        }
        
        // Tool status
        report += "🛠️ Tool Status:\n"
        let status = checkDependencies()
        
        for tool in BundleConfig.supportedTools {
            let available = isExecutableAvailable(tool)
            let foundPath = findExecutablePath(for: tool)
            let path = foundPath ?? "Not found"
            
            report += "• \(tool): \(available ? "✅ Available" : "❌ Missing")\n"
            report += "  Path: \(path)\n"
            
            if available, let toolPath = foundPath {
                // File size
                if let attributes = try? FileManager.default.attributesOfItem(atPath: toolPath),
                   let size = attributes[.size] as? Int64 {
                    let formatter = ByteCountFormatter()
                    formatter.allowedUnits = [.useMB, .useKB]
                    let sizeString = formatter.string(fromByteCount: size)
                    report += "  Size: \(sizeString)\n"
                }
                
                // Permissions
                if let attributes = try? FileManager.default.attributesOfItem(atPath: toolPath),
                   let permissions = attributes[.posixPermissions] as? NSNumber {
                    report += "  Permissions: \(String(permissions.uint16Value, radix: 8))\n"
                }
            }
            
            report += "\n"
        }
        
        // Summary
        report += "📊 Summary:\n"
        report += "• Available tools: \(BundleConfig.supportedTools.filter { isExecutableAvailable($0) }.count)/\(BundleConfig.supportedTools.count)\n"
        report += "• Status: \(status.allAvailable ? "✅ All tools ready" : "⚠️ Some tools missing")\n"
        
        return report
    }
}

// MARK: - Quarantine Management Helper

struct QuarantineManager {
    static func removeQuarantine(from path: String) async -> Bool {
        print("🏷️ Removing quarantine from: \(path)")
        
        let commands = [
            ["/usr/bin/xattr", "-d", "com.apple.quarantine", path],
            ["/usr/bin/xattr", "-c", path]
        ]
        
        for command in commands {
            let (success, output) = await ShellCommandExecutor.run(command[0], arguments: Array(command.dropFirst()))
            if success || output.contains("No such xattr") {
                print("✅ Quarantine removed from \(path)")
                return true
            }
        }
        
        print("⚠️ Could not remove quarantine from \(path)")
        return false
    }
    
    static func makeExecutable(_ path: String) async -> Bool {
        let (success, output) = await ShellCommandExecutor.run("/bin/chmod", arguments: ["+x", path])
        
        if success {
            print("✅ Made executable: \(path)")
        } else {
            print("⚠️ Failed to make executable: \(path) - \(output)")
        }
        
        return success
    }
}

// MARK: - Shell Command Executor

struct ShellCommandExecutor {
    static func run(_ command: String, arguments: [String] = []) async -> (success: Bool, output: String) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: command)
                process.arguments = arguments
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    let success = process.terminationStatus == 0
                    
                    continuation.resume(returning: (success, output))
                } catch {
                    continuation.resume(returning: (false, "Process error: \(error.localizedDescription)"))
                }
            }
        }
    }
}
