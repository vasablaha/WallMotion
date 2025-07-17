//
//  DependenciesManager.swift
//  WallMotion
//
//  Manages installation of external dependencies (Homebrew, yt-dlp, FFmpeg)
//

import Foundation
import SwiftUI

@MainActor
class DependenciesManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isInstalling = false
    @Published var installationProgress: Double = 0.0
    @Published var installationMessage = ""
    @Published var lastCheckTime = Date()
    
    // MARK: - Private Properties
    private var installationTask: Process?
    
    // MARK: - Dependency Status
    
    struct DependencyStatus {
        let ytdlp: Bool
        let ffmpeg: Bool
        let homebrew: Bool
        
        var allInstalled: Bool {
            return ytdlp && ffmpeg
        }
        
        var missing: [String] {
            var missing: [String] = []
            if !homebrew { missing.append("Homebrew") }
            if !ytdlp { missing.append("yt-dlp") }
            if !ffmpeg { missing.append("FFmpeg") }
            return missing
        }
    }
    
    // MARK: - Public Methods
    
    func checkDependencies() -> DependencyStatus {
        let ytdlpPaths = ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp", "/usr/bin/yt-dlp"]
        let ytdlpExists = ytdlpPaths.contains { FileManager.default.fileExists(atPath: $0) }
        
        let ffmpegPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        let ffmpegExists = ffmpegPaths.contains { FileManager.default.fileExists(atPath: $0) }
        
        let homebrewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        let homebrewExists = homebrewPaths.contains { FileManager.default.fileExists(atPath: $0) }
        
        lastCheckTime = Date()
        
        return DependencyStatus(
            ytdlp: ytdlpExists,
            ffmpeg: ffmpegExists,
            homebrew: homebrewExists
        )
    }
    
    func getInstallationInstructions() -> String {
        let status = checkDependencies()
        
        if status.allInstalled {
            return "All dependencies are installed! ✅"
        }
        
        var message = "Missing dependencies detected:\n\n"
        
        for dependency in status.missing {
            message += "❌ \(dependency)\n"
        }
        
        message += "\n🚀 WallMotion can install these automatically for you!\n"
        message += "Just click the 'Install Dependencies' button below.\n\n"
        
        message += "What each dependency does:\n"
        message += "• Homebrew: Package manager for macOS\n"
        message += "• yt-dlp: Downloads videos from YouTube\n"
        message += "• FFmpeg: Processes and optimizes video files\n"
        
        return message
    }
    
    // MARK: - Automatic Installation
    
    func installDependencies() async throws {
        print("🛠️ Starting automatic dependency installation...")
        
        guard !isInstalling else {
            print("⚠️ Installation already in progress")
            return
        }
        
        isInstalling = true
        installationProgress = 0.0
        installationMessage = "Checking system..."
        
        defer {
            isInstalling = false
        }
        
        do {
            let status = checkDependencies()
            
            // Step 1: Install Homebrew if needed (40% of progress)
            if !status.homebrew {
                try await installHomebrew()
            } else {
                installationProgress = 0.4
                installationMessage = "Homebrew already installed ✅"
            }
            
            // Step 2: Install yt-dlp if needed (30% of progress)
            if !status.ytdlp {
                try await installPackage("yt-dlp", progressStart: 0.4, progressEnd: 0.7)
            } else {
                installationProgress = 0.7
                installationMessage = "yt-dlp already installed ✅"
            }
            
            // Step 3: Install FFmpeg if needed (30% of progress)
            if !status.ffmpeg {
                try await installPackage("ffmpeg", progressStart: 0.7, progressEnd: 1.0)
            } else {
                installationProgress = 1.0
                installationMessage = "FFmpeg already installed ✅"
            }
            
            // Final verification
            let finalStatus = checkDependencies()
            if finalStatus.allInstalled {
                installationProgress = 1.0
                installationMessage = "All dependencies installed successfully! 🎉"
                print("✅ All dependencies installed successfully!")
            } else {
                throw DependencyError.installationIncomplete(missing: finalStatus.missing)
            }
            
            // Show success message for 2 seconds
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
        } catch {
            installationMessage = "Installation failed: \(error.localizedDescription)"
            print("❌ Installation failed: \(error)")
            throw error
        }
    }
    
    func cancelInstallation() {
        print("🛑 Cancelling installation...")
        installationTask?.terminate()
        installationTask = nil
        isInstalling = false
        installationProgress = 0.0
        installationMessage = "Installation cancelled"
    }
    
    // MARK: - Private Installation Methods
    
    private func installHomebrew() async throws {
        print("🍺 Installing Homebrew...")
        installationMessage = "Installing Homebrew package manager..."
        
        let script = """
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        """
        
        try await runInstallationScript(
            script,
            description: "Homebrew installation",
            progressStart: 0.0,
            progressEnd: 0.4
        )
        
        // Verify Homebrew installation
        let homebrewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        let homebrewExists = homebrewPaths.contains { FileManager.default.fileExists(atPath: $0) }
        
        if !homebrewExists {
            throw DependencyError.homebrewInstallationFailed
        }
        
        installationMessage = "Homebrew installed successfully ✅"
        print("✅ Homebrew installed successfully")
    }
    
    private func installPackage(_ packageName: String, progressStart: Double, progressEnd: Double) async throws {
        print("📦 Installing \(packageName)...")
        installationMessage = "Installing \(packageName)..."
        
        let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        guard let brewPath = brewPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw DependencyError.homebrewNotFound
        }
        
        let script = "\(brewPath) install \(packageName)"
        
        try await runInstallationScript(
            script,
            description: "\(packageName) installation",
            progressStart: progressStart,
            progressEnd: progressEnd
        )
        
        installationMessage = "\(packageName) installed successfully ✅"
        print("✅ \(packageName) installed successfully")
    }
    
    private func runInstallationScript(
        _ script: String,
        description: String,
        progressStart: Double,
        progressEnd: Double
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = ["-c", script]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            // Use actor-isolated data storage
            let outputCollector = OutputCollector()
            let errorCollector = OutputCollector()
            
            // Create progress timer that's sendable
            let progressTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            progressTimer.schedule(deadline: .now(), repeating: .milliseconds(500))
            progressTimer.setEventHandler { [weak self] in
                Task { @MainActor in
                    guard let self = self, self.isInstalling else {
                        progressTimer.cancel()
                        return
                    }
                    
                    let currentProgress = self.installationProgress
                    let increment = (progressEnd - progressStart) * 0.1
                    let newProgress = min(currentProgress + increment, progressEnd - 0.01)
                    self.installationProgress = newProgress
                }
            }
            progressTimer.resume()
            
            // Monitor output
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    Task {
                        await outputCollector.append(data)
                    }
                    
                    // Update installation message with relevant output
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !trimmed.hasPrefix("=") {
                            Task { @MainActor in
                                self.installationMessage = "Installing... \(trimmed.prefix(50))"
                            }
                            break
                        }
                    }
                }
            }
            
            // Monitor errors
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    Task {
                        await errorCollector.append(data)
                    }
                }
            }
            
            task.terminationHandler = { task in
                progressTimer.cancel()
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                Task { @MainActor in
                    self.installationProgress = progressEnd
                }
                
                if task.terminationStatus == 0 {
                    print("✅ \(description) completed successfully")
                    continuation.resume()
                } else {
                    print("❌ \(description) failed with exit code: \(task.terminationStatus)")
                    
                    Task {
                        let allErrors = await errorCollector.getString()
                        let allOutput = await outputCollector.getString()
                        
                        print("Error output: \(allErrors)")
                        
                        let error = DependencyError.installationFailed(
                            description: description,
                            exitCode: task.terminationStatus,
                            output: allErrors.isEmpty ? allOutput : allErrors
                        )
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            do {
                try task.run()
                self.installationTask = task
            } catch {
                progressTimer.cancel()
                print("❌ Failed to start \(description): \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Script Generation
    
    func createInstallationScript() -> String {
        let status = checkDependencies()
        var script = "#!/bin/bash\n\n"
        script += "# WallMotion Dependencies Installer\n"
        script += "# This script will install required dependencies for YouTube video import\n\n"
        script += "echo \"🚀 WallMotion Dependencies Installer\"\n"
        script += "echo \"====================================\"\n\n"
        
        script += "# Function to check if command exists\n"
        script += "command_exists() {\n"
        script += "    command -v \"$1\" >/dev/null 2>&1\n"
        script += "}\n\n"
        
        script += "# Install Homebrew if not present\n"
        script += "if ! command_exists brew; then\n"
        script += "    echo \"📦 Installing Homebrew...\"\n"
        script += "    /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n"
        script += "    echo \"✅ Homebrew installed\"\n"
        script += "else\n"
        script += "    echo \"✅ Homebrew already installed\"\n"
        script += "fi\n\n"
        
        script += "# Update Homebrew\n"
        script += "echo \"🔄 Updating Homebrew...\"\n"
        script += "brew update\n\n"
        
        if !status.ytdlp {
            script += "# Install yt-dlp\n"
            script += "echo \"📺 Installing yt-dlp...\"\n"
            script += "brew install yt-dlp\n"
            script += "echo \"✅ yt-dlp installed\"\n\n"
        }
        
        if !status.ffmpeg {
            script += "# Install FFmpeg\n"
            script += "echo \"🎬 Installing FFmpeg...\"\n"
            script += "brew install ffmpeg\n"
            script += "echo \"✅ FFmpeg installed\"\n\n"
        }
        
        script += "# Verify installations\n"
        script += "echo \"🔍 Verifying installations...\"\n"
        script += "if command_exists yt-dlp; then\n"
        script += "    echo \"✅ yt-dlp: $(yt-dlp --version | head -1)\"\n"
        script += "else\n"
        script += "    echo \"❌ yt-dlp not found\"\n"
        script += "fi\n\n"
        
        script += "if command_exists ffmpeg; then\n"
        script += "    echo \"✅ FFmpeg: $(ffmpeg -version | head -1)\"\n"
        script += "else\n"
        script += "    echo \"❌ FFmpeg not found\"\n"
        script += "fi\n\n"
        
        script += "echo \"🎉 Installation complete!\"\n"
        script += "echo \"You can now use WallMotion's YouTube import feature.\"\n"
        
        return script
    }
    
    func saveInstallationScript() throws -> URL {
        let script = createInstallationScript()
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("wallmotion_install_dependencies.sh")
        
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        
        // Make script executable
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+x", scriptURL.path]
        try process.run()
        process.waitUntilExit()
        
        return scriptURL
    }
    
    // MARK: - Utility Methods
    
    func refreshStatus() {
        objectWillChange.send()
    }
    
    func reset() {
        cancelInstallation()
        installationProgress = 0.0
        installationMessage = ""
    }
}

// MARK: - Error Types

enum DependencyError: LocalizedError {
    case homebrewNotFound
    case homebrewInstallationFailed
    case installationFailed(description: String, exitCode: Int32, output: String)
    case installationIncomplete(missing: [String])
    case permissionDenied
    case networkError
    case unsupportedSystem
    
    var errorDescription: String? {
        switch self {
        case .homebrewNotFound:
            return "Homebrew not found. Please install Homebrew first from brew.sh"
        case .homebrewInstallationFailed:
            return "Failed to install Homebrew. Please check your internet connection and try again."
        case .installationFailed(let description, let exitCode, let output):
            return "Failed to install \(description) (exit code: \(exitCode)). Output: \(output.prefix(200))"
        case .installationIncomplete(let missing):
            return "Installation incomplete. Missing: \(missing.joined(separator: ", "))"
        case .permissionDenied:
            return "Permission denied. Please run with administrator privileges."
        case .networkError:
            return "Network error during installation. Please check your internet connection."
        case .unsupportedSystem:
            return "Unsupported system. This feature requires macOS 10.15 or later."
        }
    }
}
