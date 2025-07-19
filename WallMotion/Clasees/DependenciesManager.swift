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
    @Published var cachedDependencyStatus: DependencyStatus?
     
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
        // Pokud máme cached status, použijeme ho
        if let cached = cachedDependencyStatus {
            return cached
        }
        
        // Jinak spočítáme bez publikování změn
        return calculateDependencyStatus()
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
    
    private func calculateDependencyStatus() -> DependencyStatus {
        let ytdlpPaths = ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp", "/usr/bin/yt-dlp"]
        let ytdlpExists = ytdlpPaths.contains { FileManager.default.fileExists(atPath: $0) }
        
        let ffmpegPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        let ffmpegExists = ffmpegPaths.contains { FileManager.default.fileExists(atPath: $0) }
        
        let homebrewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        let homebrewExists = homebrewPaths.contains { FileManager.default.fileExists(atPath: $0) }
        
        return DependencyStatus(
            ytdlp: ytdlpExists,
            ffmpeg: ffmpegExists,
            homebrew: homebrewExists
        )
    }
    
    func refreshStatus() {
        let newStatus = calculateDependencyStatus()
        cachedDependencyStatus = newStatus
        lastCheckTime = Date()
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
                // Refresh status after installation
                refreshStatus()
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
                refreshStatus() // Použijeme refresh místo checkDependencies
                let finalStatus = cachedDependencyStatus ?? calculateDependencyStatus()
                if finalStatus.allInstalled {
                    installationProgress = 1.0
                    installationMessage = "All dependencies installed successfully! 🎉"
                    print("✅ All dependencies installed successfully!")
                } else {
                    throw DependencyError.installationFailed(
                        description: "Final verification failed",
                        exitCode: -1,
                        output: "Some dependencies still missing after installation"
                    )
                }
                
            } catch {
                installationProgress = 0.0
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
        
        // Kontrola, zda už není Homebrew nainstalovaný
        let homebrewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        let homebrewExists = homebrewPaths.contains { FileManager.default.fileExists(atPath: $0) }
        
        if homebrewExists {
            installationProgress = 0.4
            installationMessage = "Homebrew already installed ✅"
            print("✅ Homebrew already installed")
            return
        }
        
        // V sandboxu nemůžeme přímo instalovat Homebrew
        // Místo toho zobrazíme uživateli instrukce a otevřeme Terminal
        await MainActor.run {
            showHomebrewInstallationDialog()
        }
        
        throw DependencyError.permissionDenied
    }

    
    @MainActor
    private func showHomebrewInstallationDialog() {
        let alert = NSAlert()
        alert.messageText = "Homebrew Installation Required"
        alert.informativeText = """
        WallMotion needs to install Homebrew to download YouTube videos.
        
        Due to security restrictions, this must be done manually:
        
        1. Open Terminal (⌘+Space, type "Terminal")
        2. Paste and run this command:
        
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        3. After installation, restart WallMotion
        
        Would you like to:
        """
        
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Terminal & Copy Command")
        alert.addButton(withTitle: "Copy Command Only")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        let installCommand = "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        
        switch response {
        case .alertFirstButtonReturn:
            // Open Terminal and copy command
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(installCommand, forType: .string)
            
            if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                NSWorkspace.shared.open(terminalURL)
            }
            
        case .alertSecondButtonReturn:
            // Copy command only
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(installCommand, forType: .string)
            
            let copyAlert = NSAlert()
            copyAlert.messageText = "Command Copied!"
            copyAlert.informativeText = "The installation command has been copied to your clipboard. Open Terminal and paste it."
            copyAlert.addButton(withTitle: "OK")
            copyAlert.runModal()
            
        default:
            break
        }
    }

    private func installPackage(_ packageName: String, progressStart: Double, progressEnd: Double) async throws {
        print("📦 Installing \(packageName)...")
        installationMessage = "Installing \(packageName)..."
        
        let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        guard let brewPath = brewPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            await MainActor.run {
                showMissingHomebrewDialog()
            }
            throw DependencyError.homebrewNotFound
        }
        
        // Pokus o instalaci s lepším error handling
        do {
            try await runBrewCommand(brewPath: brewPath, command: "install \(packageName)", progressStart: progressStart, progressEnd: progressEnd)
            installationMessage = "\(packageName) installed successfully ✅"
            print("✅ \(packageName) installed successfully")
        } catch {
            // Pokud instalace selže, nabídni manuální instrukce
            await MainActor.run {
                showManualInstallationDialog(for: packageName, brewPath: brewPath)
            }
            throw error
        }
    }

    
    @MainActor
    private func showMissingHomebrewDialog() {
        let alert = NSAlert()
        alert.messageText = "Homebrew Not Found"
        alert.informativeText = """
        Homebrew package manager is required but not installed.
        
        Please install Homebrew first by running this command in Terminal:
        
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        Then restart WallMotion.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "OK")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let installCommand = "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(installCommand, forType: .string)
        }
    }
    
    @MainActor
    private func showManualInstallationDialog(for packageName: String, brewPath: String) {
        let alert = NSAlert()
        alert.messageText = "\(packageName.capitalized) Installation Failed"
        alert.informativeText = """
        Automatic installation failed due to security restrictions.
        
        Please install \(packageName) manually by running this command in Terminal:
        
        \(brewPath) install \(packageName)
        
        Then restart WallMotion or click "Refresh Status".
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "Refresh Status")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Copy command
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(brewPath) install \(packageName)", forType: .string)
            
        case .alertSecondButtonReturn:
            // Refresh status
            refreshStatus()
            
        default:
            break
        }
    }
    
    // Nová metoda pro spouštění brew příkazů s Swift 6 kompatibilitou
    private func runBrewCommand(brewPath: String, command: String, progressStart: Double, progressEnd: Double) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: brewPath)
            task.arguments = command.components(separatedBy: " ")
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            // Swift 6 compatible progress tracking using Task instead of Timer
            let progressTask = Task { @MainActor in
                let progressIncrement = (progressEnd - progressStart) * 0.1
                
                while !Task.isCancelled && task.isRunning {
                    self.installationProgress = min(progressEnd, self.installationProgress + progressIncrement)
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
            }
            
            task.terminationHandler = { process in
                // Cancel progress task
                progressTask.cancel()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                Task { @MainActor in
                    self.installationProgress = progressEnd
                }
                
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let error = DependencyError.installationFailed(
                        description: command,
                        exitCode: process.terminationStatus,
                        output: errorOutput.isEmpty ? output : errorOutput
                    )
                    continuation.resume(throwing: error)
                }
            }
            
            do {
                try task.run()
                self.installationTask = task
            } catch {
                progressTask.cancel()
                print("❌ Failed to start \(command): \(error)")
                continuation.resume(throwing: error)
            }
        }
    }


    // Přidání nové veřejné metody pro manual refresh
    func checkAndRefreshDependencies() {
        refreshStatus()
        
        let status = checkDependencies()
        
        if status.allInstalled {
            Task { @MainActor in
                let alert = NSAlert()
                alert.messageText = "Dependencies Check"
                alert.informativeText = "✅ All dependencies are properly installed!"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        } else {
            Task { @MainActor in
                let missing = status.missing.joined(separator: ", ")
                let alert = NSAlert()
                alert.messageText = "Missing Dependencies"
                alert.informativeText = "❌ Still missing: \(missing)\n\nPlease install them manually using Terminal."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Show Instructions")
                alert.addButton(withTitle: "OK")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    showInstallationInstructionsDialog()
                }
            }
        }
    }

    @MainActor
    private func showInstallationInstructionsDialog() {
        let status = checkDependencies()
        var instructions = "Manual Installation Instructions:\n\n"
        
        if !status.homebrew {
            instructions += "1. Install Homebrew:\n"
            instructions += "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n\n"
        }
        
        if !status.ytdlp {
            instructions += "2. Install yt-dlp:\n"
            instructions += "brew install yt-dlp\n\n"
        }
        
        if !status.ffmpeg {
            instructions += "3. Install FFmpeg:\n"
            instructions += "brew install ffmpeg\n\n"
        }
        
        instructions += "After installation, restart WallMotion or click 'Refresh Status'."
        
        let alert = NSAlert()
        alert.messageText = "Installation Instructions"
        alert.informativeText = instructions
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy All Commands")
        alert.addButton(withTitle: "OK")
        
        if alert.runModal() == .alertFirstButtonReturn {
            var commands = ""
            if !status.homebrew {
                commands += "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n"
            }
            if !status.ytdlp {
                commands += "brew install yt-dlp\n"
            }
            if !status.ffmpeg {
                commands += "brew install ffmpeg\n"
            }
            
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(commands, forType: .string)
        }
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
