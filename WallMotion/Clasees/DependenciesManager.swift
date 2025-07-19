//
//  DependenciesManager.swift
//  WallMotion
//

import Foundation
import SwiftUI

@MainActor
class DependenciesManager: ObservableObject {
    @Published var installationProgress: Double = 0.0
    @Published var installationMessage: String = ""
    @Published var isInstalling: Bool = false
    
    private var installationTask: Process?
    
    struct DependencyStatus {
        let homebrew: Bool
        let ytdlp: Bool
        let ffmpeg: Bool
        
        var allInstalled: Bool {
            return homebrew && ytdlp && ffmpeg
        }
        
        var missing: [String] {
            var missing: [String] = []
            if !homebrew { missing.append("Homebrew") }
            if !ytdlp { missing.append("yt-dlp") }
            if !ffmpeg { missing.append("FFmpeg") }
            return missing
        }
    }
    
    func checkDependencies() -> DependencyStatus {
        print("🔍 Starting dependency check...")
        
        print("🔍 Checking Homebrew...")
        let homebrewExists = checkHomebrewInstallation()
        print("🔍 Homebrew result: \(homebrewExists)")
        
        print("🔍 Checking yt-dlp...")
        let ytdlpExists = checkCommand("yt-dlp")
        print("🔍 yt-dlp result: \(ytdlpExists)")
        
        print("🔍 Checking ffmpeg...")
        let ffmpegExists = checkCommand("ffmpeg")
        print("🔍 ffmpeg result: \(ffmpegExists)")
        
        print("🔍 Creating DependencyStatus...")
        let status = DependencyStatus(
            homebrew: homebrewExists,
            ytdlp: ytdlpExists,
            ffmpeg: ffmpegExists
        )
        print("🔍 Dependency check complete!")
        
        return status
    }
    
    private func checkHomebrewInstallation() -> Bool {
        print("🍺 Checking Homebrew paths...")
        let homebrewPaths = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "/home/linuxbrew/.linuxbrew/bin/brew"
        ]
        
        for path in homebrewPaths {
            print("🍺 Checking path: \(path)")
            let exists = FileManager.default.fileExists(atPath: path)
            print("🍺 Path \(path) exists: \(exists)")
            if exists {
                return true
            }
        }
        
        print("🍺 No Homebrew found")
        return false
    }
    
    private func checkCommand(_ command: String) -> Bool {
        print("⚙️ Checking command: \(command)")
        
        // Místo which použij přímou kontrolu cest
        let commonPaths = [
            "/opt/homebrew/bin/\(command)",
            "/usr/local/bin/\(command)",
            "/usr/bin/\(command)",
            "/bin/\(command)"
        ]
        
        for path in commonPaths {
            print("⚙️ Checking path: \(path)")
            let exists = FileManager.default.fileExists(atPath: path)
            print("⚙️ Path \(path) exists: \(exists)")
            if exists {
                print("⚙️ Command \(command) found at: \(path)")
                return true
            }
        }
        
        print("⚙️ Command \(command) not found in any common path")
        return false
    }
    
    func refreshStatus() {
        objectWillChange.send()
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
    
    // MARK: - Hlavní instalační metoda s admin oprávněními
    
    func installDependencies() async throws {
        guard !isInstalling else { return }
        
        isInstalling = true
        installationProgress = 0.0
        installationMessage = "Starting installation..."
        
        defer {
            isInstalling = false
        }
        
        do {
            // Použijeme sudo nebo osascript pro zvýšená oprávnění
            try await installWithAdminRights()
            
            // Finální ověření
            let finalStatus = checkDependencies()
            if finalStatus.allInstalled {
                installationProgress = 1.0
                installationMessage = "All dependencies installed successfully! 🎉"
                print("✅ All dependencies installed successfully!")
            } else {
                throw DependencyError.installationIncomplete(missing: finalStatus.missing)
            }
            
        } catch {
            installationProgress = 0.0
            installationMessage = "Installation failed: \(error.localizedDescription)"
            print("❌ Installation failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Instalace s admin oprávněními
    
    private func installWithAdminRights() async throws {
        installationMessage = "Requesting administrator privileges..."
        installationProgress = 0.1
        
        let script = createInstallationScript()
        let scriptPath = try saveInstallationScript(script)
        
        // Použijeme osascript pro spuštění s admin oprávněními
        try await runScriptWithAdminRights(scriptPath: scriptPath.path)
    }
    
    private func runScriptWithAdminRights(scriptPath: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = """
                do shell script "bash '\(scriptPath)'" with administrator privileges
                """
                
                var error: NSDictionary?
                let script = NSAppleScript(source: appleScript)
                
                DispatchQueue.main.async {
                    self.updateProgress(0.2, "Installing Homebrew...")
                }
                
                let result = script?.executeAndReturnError(&error)
                
                DispatchQueue.main.async {
                    if let error = error {
                        print("AppleScript error: \(error)")
                        continuation.resume(throwing: DependencyError.installationFailed(
                            description: "Admin installation failed",
                            exitCode: -1,
                            output: error.description
                        ))
                    } else {
                        print("Installation completed successfully")
                        self.updateProgress(1.0, "Installation completed!")
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    // MARK: - Vylepšený instalační skript
    
    private func createInstallationScript() -> String {
        let status = checkDependencies()
        var script = "#!/bin/bash\n\n"
        script += "set -e\n"  // Exit on any error
        script += "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\"\n\n"
        
        script += "echo \"🚀 WallMotion Dependencies Installer\"\n"
        script += "echo \"====================================\"\n\n"
        
        // Funkce pro kontrolu příkazů
        script += """
        command_exists() {
            command -v "$1" >/dev/null 2>&1
        }

        """
        
        // Instalace Homebrew
        if !status.homebrew {
            script += """
            if ! command_exists brew; then
                echo "🍺 Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                
                # Add Homebrew to PATH for Apple Silicon Macs
                if [[ -f "/opt/homebrew/bin/brew" ]]; then
                    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                fi
                
                # Add Homebrew to PATH for Intel Macs
                if [[ -f "/usr/local/bin/brew" ]]; then
                    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
                    eval "$(/usr/local/bin/brew shellenv)"
                fi
                
                echo "✅ Homebrew installed successfully"
            else
                echo "✅ Homebrew already installed"
            fi

            """
        }
        
        // Update Homebrew
        script += """
        echo "🔄 Updating Homebrew..."
        brew update || echo "⚠️ Homebrew update failed, continuing..."

        """
        
        // Instalace yt-dlp
        if !status.ytdlp {
            script += """
            if ! command_exists yt-dlp; then
                echo "📺 Installing yt-dlp..."
                brew install yt-dlp
                echo "✅ yt-dlp installed successfully"
            else
                echo "✅ yt-dlp already installed"
            fi

            """
        }
        
        // Instalace FFmpeg
        if !status.ffmpeg {
            script += """
            if ! command_exists ffmpeg; then
                echo "🎬 Installing FFmpeg..."
                brew install ffmpeg
                echo "✅ FFmpeg installed successfully"
            else
                echo "✅ FFmpeg already installed"
            fi

            """
        }
        
        // Finální ověření
        script += """
        echo ""
        echo "🔍 Verifying installations..."
        
        if command_exists brew; then
            echo "✅ Homebrew: $(brew --version | head -1)"
        else
            echo "❌ Homebrew not found"
            exit 1
        fi

        if command_exists yt-dlp; then
            echo "✅ yt-dlp: $(yt-dlp --version 2>/dev/null || echo 'installed')"
        else
            echo "❌ yt-dlp not found"
            exit 1
        fi

        if command_exists ffmpeg; then
            echo "✅ FFmpeg: $(ffmpeg -version 2>/dev/null | head -1 | cut -d' ' -f1-3)"
        else
            echo "❌ FFmpeg not found"
            exit 1
        fi

        echo ""
        echo "🎉 All dependencies installed successfully!"
        echo "You can now close this window and use WallMotion's YouTube import feature."
        """
        
        return script
    }
    
    private func saveInstallationScript(_ script: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("wallmotion_install_dependencies.sh")
        
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        
        // Make script executable
        let chmodProcess = Process()
        chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmodProcess.arguments = ["+x", scriptURL.path]
        try chmodProcess.run()
        chmodProcess.waitUntilExit()
        
        return scriptURL
    }
    
    // MARK: - Helper methods
    
    private func updateProgress(_ progress: Double, _ message: String) {
        self.installationProgress = progress
        self.installationMessage = message
    }
    
    func cancelInstallation() {
        print("🛑 Cancelling installation...")
        installationTask?.terminate()
        installationTask = nil
        isInstalling = false
        installationProgress = 0.0
        installationMessage = "Installation cancelled"
    }
    
    func reset() {
        cancelInstallation()
        installationProgress = 0.0
        installationMessage = ""
    }
    
    // MARK: - Původní metody pro zpětnou kompatibilitu
    
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
    
    // MARK: - Fallback manual installation methods
    
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
        alert.addButton(withTitle: "Open Terminal")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            let command = "\(brewPath) install \(packageName)"
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            
            let copyAlert = NSAlert()
            copyAlert.messageText = "Command Copied"
            copyAlert.informativeText = "The installation command has been copied to your clipboard. Open Terminal and paste it."
            copyAlert.addButton(withTitle: "OK")
            copyAlert.runModal()
            
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
            
        default:
            break
        }
    }
    
    @MainActor
    func showManualInstallationInstructions() {
        let alert = NSAlert()
        alert.messageText = "Manual Installation Required"
        alert.informativeText = createManualInstructions()
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy Commands")
        alert.addButton(withTitle: "Open Terminal")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            copyManualCommands()
        case .alertSecondButtonReturn:
            openTerminal()
        default:
            break
        }
    }
    
    private func createManualInstructions() -> String {
        let status = checkDependencies()
        var instructions = "Please install the missing dependencies manually:\n\n"
        
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
        return instructions
    }
    
    private func copyManualCommands() {
        let commands = """
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        brew install yt-dlp
        brew install ffmpeg
        """
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(commands, forType: .string)
        
        let alert = NSAlert()
        alert.messageText = "Commands Copied"
        alert.informativeText = "The installation commands have been copied to your clipboard. Open Terminal and paste them."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func openTerminal() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
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
    private func showHomebrewInstallationDialog() {
        let alert = NSAlert()
        alert.messageText = "Homebrew Installation Required"
        alert.informativeText = """
        WallMotion needs to install Homebrew to download YouTube videos.
        
        Due to security restrictions, this must be done manually:
        
        1. Open Terminal (⌘+Space, type "Terminal")
        2. Paste and run this command:
        
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        3. Restart WallMotion after installation
        """
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "Open Terminal")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            let installCommand = "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(installCommand, forType: .string)
            
            let copyAlert = NSAlert()
            copyAlert.messageText = "Command Copied"
            copyAlert.informativeText = "The installation command has been copied to your clipboard. Open Terminal and paste it."
            copyAlert.addButton(withTitle: "OK")
            copyAlert.runModal()
            
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
            
        default:
            break
        }
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
            return "Homebrew package manager not found"
        case .homebrewInstallationFailed:
            return "Failed to install Homebrew. Please check your internet connection and try again."
        case .installationFailed(let description, let exitCode, let output):
            return "Failed to install \(description) (exit code: \(exitCode)). Output: \(output.prefix(200))"
        case .installationIncomplete(let missing):
            return "Installation incomplete. Missing: \(missing.joined(separator: ", "))"
        case .permissionDenied:
            return "Permission denied. Administrator privileges required."
        case .networkError:
            return "Network error during installation. Please check your internet connection."
        case .unsupportedSystem:
            return "Unsupported system configuration"
        }
    }
}
