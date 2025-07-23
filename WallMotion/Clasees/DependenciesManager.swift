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
    
    // MARK: - Enhanced checkDependencies s quarantine fix
    func checkDependencies() -> DependencyStatus {
        print("🔍 Starting dependency check...")
        
        // NOVÉ: První spusť quarantine fix
        Task {
            await fixBundledExecutablesQuarantine()
        }
        
        print("🔍 Checking Homebrew...")
        let homebrewExists = checkHomebrewInstallation()
        print("🔍 Homebrew result: \(homebrewExists)")
        
        print("🔍 Checking yt-dlp...")
        let ytdlpExists = checkCommand("yt-dlp")
        print("🔍 yt-dlp result: \(ytdlpExists)")
        
        print("🔍 Checking ffmpeg...")
        let ffmpegExists = checkCommand("ffmpeg")
        print("🔍 ffmpeg result: \(ffmpegExists)")
        
        let status = DependencyStatus(
            homebrew: homebrewExists,
            ytdlp: ytdlpExists,
            ffmpeg: ffmpegExists
        )
        
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
        print("⚙️ Enhanced checking command: \(command)")
        
        // 1. Debug: Zkontroluj bundle structure
        if let resourcePath = Bundle.main.resourcePath {
            print("🔍 Bundle resource path: \(resourcePath)")
            
            // List všechny soubory v Resources
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("🔍 Bundle contents: \(contents)")
                
                // Specifically check for our tools
                for tool in ["yt-dlp", "ffmpeg", "ffprobe"] {
                    let toolPath = "\(resourcePath)/\(tool)"
                    let exists = FileManager.default.fileExists(atPath: toolPath)
                    let executable = FileManager.default.isExecutableFile(atPath: toolPath)
                    print("🔍 Tool \(tool): exists=\(exists), executable=\(executable), path=\(toolPath)")
                    
                    // Check permissions
                    if exists {
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: toolPath)
                            if let permissions = attributes[.posixPermissions] as? NSNumber {
                                print("🔍 Tool \(tool) permissions: \(String(permissions.uint16Value, radix: 8))")
                            }
                        } catch {
                            print("🔍 Error reading \(tool) attributes: \(error)")
                        }
                    }
                }
            } catch {
                print("❌ Error listing bundle contents: \(error)")
            }
        }
        
        // 2. Try findExecutablePath (comprehensive search)
        if let foundPath = findExecutablePath(for: command) {
            print("✅ Found \(command) at: \(foundPath)")
            
            // Test executability
            let isExecutable = FileManager.default.isExecutableFile(atPath: foundPath)
            print("🔧 \(command) executable test: \(isExecutable)")
            
            // Try to run version command
            Task {
                let versionResult = await testCommandVersion(foundPath, command: command)
                print("🧪 \(command) version test: \(versionResult)")
            }
            
            return true
        }
        
        print("❌ \(command) not found anywhere")
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
    
    // MARK: - Test command execution
    private func testCommandVersion(_ path: String, command: String) async -> String {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: path)
                
                // Different version args for different tools
                let versionArgs: [String]
                switch command {
                case "yt-dlp":
                    versionArgs = ["--version"]
                case "ffmpeg":
                    versionArgs = ["-version"]
                case "ffprobe":
                    versionArgs = ["-version"]
                default:
                    versionArgs = ["--version"]
                }
                
                task.arguments = versionArgs
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe
                
                // Timeout protection
                var timedOut = false
                DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                    if task.isRunning {
                        task.terminate()
                        timedOut = true
                    }
                }
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    if timedOut {
                        continuation.resume(returning: "TIMEOUT")
                        return
                    }
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    let result = task.terminationStatus == 0 ? "SUCCESS: \(output.prefix(50))" : "FAILED (exit \(task.terminationStatus)): \(output.prefix(50))"
                    
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(returning: "ERROR: \(error)")
                }
            }
        }
    }
    
    // MARK: - Hlavní instalační metoda s admin oprávněními
    
    func installDependencies() async throws {
        guard !isInstalling else { return }
        
        isInstalling = true
        installationProgress = 0.0
        installationMessage = "Starting enhanced installation..."
        
        defer { isInstalling = false }
        
        do {
            // 1. Pre-install diagnostics
            installationMessage = "Running pre-install diagnostics..."
            let diagnostics = performDiagnostics()
            print("📋 Pre-install diagnostics:\n\(diagnostics)")
            
            // 2. Test external process capability
            installationMessage = "Testing external process permissions..."
            let (canRunProcesses, processTestOutput) = await testExternalProcess()
            print("🧪 Process test result: \(processTestOutput)")
            
            if !canRunProcesses {
                throw DependencyError.permissionDenied("Cannot run external processes. Check entitlements.")
            }
            
            // 3. Enhanced installation attempt
            try await performEnhancedInstallation()
            
            // 4. Post-install verification
            installationMessage = "Verifying installation..."
            let finalStatus = checkDependencies()
            
            if finalStatus.allInstalled {
                installationProgress = 1.0
                installationMessage = "✅ All dependencies installed successfully!"
                
                // Post-install diagnostics
                let postDiagnostics = performDiagnostics()
                print("📋 Post-install diagnostics:\n\(postDiagnostics)")
            } else {
                throw DependencyError.installationIncomplete(missing: finalStatus.missing)
            }
            
        } catch {
            installationProgress = 0.0
            installationMessage = "❌ Installation failed: \(error.localizedDescription)"
            
            // Error diagnostics
            let errorDiagnostics = performDiagnostics()
            print("📋 Error diagnostics:\n\(errorDiagnostics)")
            
            throw error
        }
    }

    private func performEnhancedInstallation() async throws {
        let status = checkDependencies()
        
        if status.homebrew {
            // Máme homebrew, jen instaluj packages
            try await installBrewPackagesEnhanced()
        } else {
            // Zkus automatic homebrew installation s Admin privileges
            try await installHomebrewWithAdminRights()
            
            // Po instalaci homebrew zkus packages
            try await installBrewPackagesEnhanced()
        }
    }

    private func installHomebrewWithAdminRights() async throws {
        installationMessage = "Installing Homebrew with administrator rights..."
        installationProgress = 0.1
        
        let script = """
        #!/bin/bash
        export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
        
        if ! command -v brew >/dev/null 2>&1; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            
            # Ensure PATH is updated
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [[ -f "/usr/local/bin/brew" ]]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
        fi
        
        brew --version
        """
        
        try await runAdminScript(script)
        installationProgress = 0.4
    }

    private func installBrewPackagesEnhanced() async throws {
        guard let brewPath = findExecutablePath(for: "brew") else {
            throw DependencyError.homebrewNotFound
        }
        
        let status = checkDependencies()
        installationMessage = "Installing missing packages..."
        installationProgress = 0.5
        
        if !status.ytdlp {
            try await runBrewCommandEnhanced(brewPath: brewPath, command: "install yt-dlp")
            installationProgress = 0.7
        }
        
        if !status.ffmpeg {
            try await runBrewCommandEnhanced(brewPath: brewPath, command: "install ffmpeg")
            installationProgress = 0.9
        }
    }

    private func runBrewCommandEnhanced(brewPath: String, command: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: brewPath)
                task.arguments = command.components(separatedBy: " ")
                
                // Enhanced environment
                var environment = ProcessInfo.processInfo.environment
                environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "")
                task.environment = environment
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = errorPipe
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    if task.terminationStatus == 0 {
                        print("✅ Brew command succeeded: \(command)")
                        continuation.resume()
                    } else {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        print("❌ Brew command failed: \(command)\nError: \(errorString)")
                        
                        let error = DependencyError.installationFailed(
                            description: "Brew command failed: \(command)",
                            exitCode: task.terminationStatus,
                            output: errorString
                        )
                        continuation.resume(throwing: error)
                    }
                } catch {
                    print("❌ Failed to run brew command: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runAdminScript(_ script: String) async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("install_homebrew.sh")
        
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        
        // Make executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = """
                do shell script "bash '\(scriptURL.path)'" with administrator privileges
                """
                
                var error: NSDictionary?
                let script = NSAppleScript(source: appleScript)
                _ = script?.executeAndReturnError(&error)
                
                // Cleanup
                try? FileManager.default.removeItem(at: scriptURL)
                
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Admin script error: \(error)")
                        let nsError = NSError(domain: "AdminScript", code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: error.description])
                        continuation.resume(throwing: nsError)
                    } else {
                        print("✅ Admin script completed successfully")
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    // MARK: - Instalace s admin oprávněními
    
    private func installWithAdminRights() async throws {
        installationMessage = "Installing dependencies..."
        installationProgress = 0.1
        
        let status = checkDependencies()
        
        // Pokud máme Homebrew, jen nainstaluj balíčky
        if status.homebrew {
            try await installBrewPackages()
        } else {
            // Pokud nemáme Homebrew, zobraz manuální instrukce
            await MainActor.run {
                showHomebrewInstallationDialog()
            }
            throw DependencyError.homebrewNotFound
        }
    }
    
    private func installBrewPackages() async throws {
        let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        guard let brewPath = brewPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw DependencyError.homebrewNotFound
        }
        
        let status = checkDependencies()
        
        installationMessage = "Installing missing packages..."
        installationProgress = 0.3
        
        if !status.ytdlp {
            try await runBrewCommand(brewPath: brewPath, command: "install yt-dlp", progressStart: 0.3, progressEnd: 0.6)
        }
        
        if !status.ffmpeg {
            try await runBrewCommand(brewPath: brewPath, command: "install ffmpeg", progressStart: 0.6, progressEnd: 0.9)
        }
        
        installationProgress = 1.0
        installationMessage = "Installation completed!"
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
                
                _ = script?.executeAndReturnError(&error)
                
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
    
    // MARK: - Public Path Resolution (pro use v jiných třídách)
    
    // Dočasně přidejte do findExecutablePath v DependenciesManager.swift

    func findExecutablePath(for command: String) -> String? {
        print("🔍 Enhanced search for: \(command)")
        
        // 1. PRIORITA: Bundled executables (zkus první)
        if let bundledPath = findBundledExecutable(command) {
            print("✅ Found bundled: \(bundledPath)")
            
            // ✅ NOVÉ: Pro yt-dlp otestuj, jestli skutečně funguje
            if command == "yt-dlp" {
                let works = testYtDlpFunctionality(bundledPath)
                if works {
                    print("✅ Bundled yt-dlp works!")
                    return bundledPath
                } else {
                    print("❌ Bundled yt-dlp failed, trying system fallback...")
                }
            } else {
                // Pro ffmpeg a ffprobe používej bundled vždy
                return bundledPath
            }
        }
        
        // 2. FALLBACK: System paths (especially pro yt-dlp když bundled selže)
        if let systemPath = findSystemExecutable(command) {
            print("✅ Found system: \(systemPath)")
            
            // Test system tool
            if command == "yt-dlp" {
                let works = testYtDlpFunctionality(systemPath)
                if works {
                    print("✅ System yt-dlp works!")
                    return systemPath
                } else {
                    print("❌ System yt-dlp also failed")
                }
            } else {
                return systemPath
            }
        }
        
        print("❌ \(command) not found anywhere")
        return nil
    }
    
    private func testYtDlpFunctionality(_ path: String) -> Bool {
        print("🧪 Testing yt-dlp functionality at: \(path)")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = ["--version"]
        
        // Enhanced environment for PyInstaller
        var environment = ProcessInfo.processInfo.environment
        environment["TMPDIR"] = NSTemporaryDirectory()
        environment["TEMP"] = NSTemporaryDirectory()
        environment["TMP"] = NSTemporaryDirectory()
        environment["PYINSTALLER_SEMAPHORE"] = "0"
        environment["PYI_DISABLE_SEMAPHORE"] = "1"
        environment["_PYI_SPLASH_IPC"] = "0"
        environment["OBJC_DISABLE_INITIALIZE_FORK_SAFETY"] = "YES"
        environment["PYTHONPATH"] = ""  // Clear Python path
        environment["PYTHONHOME"] = ""  // Clear Python home
        
        task.environment = environment
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let success = task.terminationStatus == 0 && !output.contains("Error loading Python lib")
            
            print("🧪 Test result: \(success ? "✅ SUCCESS" : "❌ FAILED")")
            if !success && !output.isEmpty {
                print("🧪 Output: \(output.prefix(200))")
            }
            
            return success
        } catch {
            print("🧪 Test failed to run: \(error)")
            return false
        }
    }
    
    
    private func findBundledExecutable(_ command: String) -> String? {
        print("🔍 Searching bundled executable: \(command)")
        
        guard let resourcePath = Bundle.main.resourcePath else {
            print("❌ No resource path")
            return nil
        }
        
        // Všechny možné lokace v bundle
        let bundledPaths = [
            "\(resourcePath)/\(command)",
            "\(resourcePath)/Executables/\(command)",
            "\(resourcePath)/bin/\(command)",
            "\(resourcePath)/tools/\(command)"
        ]
        
        for path in bundledPaths {
            print("🔍 Checking bundled path: \(path)")
            
            let fileManager = FileManager.default
            
            if fileManager.fileExists(atPath: path) {
                print("📁 File exists at: \(path)")
                
                // Zkontroluj, zda je executable
                let isExecutable = fileManager.isExecutableFile(atPath: path)
                print("🔧 Is executable: \(isExecutable)")
                
                if isExecutable {
                    print("✅ Bundled executable ready: \(path)")
                    return path
                } else {
                    print("⚠️ File exists but not executable, trying to fix...")
                    
                    // Pokus o opravu permissions
                    Task {
                        await makeExecutable(path)
                        await removeQuarantineFlag(from: path)
                    }
                    
                    // Zkus znovu po chvilce
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if fileManager.isExecutableFile(atPath: path) {
                            print("✅ Fixed bundled executable: \(path)")
                        }
                    }
                    
                    return path // Vrať i tak, možná se opraví
                }
            }
        }
        
        print("❌ No bundled \(command) found")
        return nil
    }

    private func findSystemExecutable(_ command: String) -> String? {
        print("🔍 Searching system executable: \(command)")
        
        // Standard paths na macOS
        let systemPaths = [
            "/opt/homebrew/bin/\(command)",
            "/usr/local/bin/\(command)",
            "/usr/bin/\(command)",
            "/bin/\(command)"
        ]
        
        for path in systemPaths {
            print("🔍 Checking system path: \(path)")
            
            if FileManager.default.isExecutableFile(atPath: path) {
                print("✅ System executable found: \(path)")
                return path
            }
        }
        
        // Fallback: zkus `which` command
        if let whichPath = findWithWhichCommand(command) {
            print("✅ Found via which: \(whichPath)")
            return whichPath
        }
        
        print("❌ No system \(command) found")
        return nil
    }

    
    private func findWithWhichCommand(_ command: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let path = output, !path.isEmpty {
                    return path
                }
            }
        } catch {
            print("❌ which command failed: \(error)")
        }
        
        return nil
    }
    
    
    private func resolveWildcardPath(_ pathPattern: String) -> String? {
        // Resolve paths like "/opt/homebrew/Cellar/ffmpeg/*/bin/ffmpeg"
        let components = pathPattern.components(separatedBy: "/")
        guard let wildcardIndex = components.firstIndex(of: "*") else {
            return nil
        }
        
        let beforeWildcard = components[0..<wildcardIndex].joined(separator: "/")
        let afterWildcard = components[(wildcardIndex + 1)...].joined(separator: "/")
        
        do {
            let parentDir = beforeWildcard.isEmpty ? "/" : beforeWildcard
            let contents = try FileManager.default.contentsOfDirectory(atPath: parentDir)
            
            for item in contents.sorted().reversed() { // Nejnovější verze první
                let candidatePath = "\(parentDir)/\(item)/\(afterWildcard)"
                if FileManager.default.fileExists(atPath: candidatePath) &&
                   FileManager.default.isExecutableFile(atPath: candidatePath) {
                    return candidatePath
                }
            }
        } catch {
            print("❌ Error resolving wildcard path \(pathPattern): \(error)")
        }
        
        return nil
    }
    
    private func checkWithWhichCommand(_ command: String) -> Bool {
        // Fallback using system 'which' command
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !output.isEmpty {
                    print("✅ Found \(command) via which: \(output)")
                    return true
                }
            }
        } catch {
            print("❌ Which command failed for \(command): \(error)")
        }
        
        return false
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
    
    // MARK: - Quarantine Fix pro DMG
    func fixBundledExecutablesQuarantine() async {
        print("🔧 Fixing bundled executables quarantine...")
        
        let tools = ["yt-dlp", "ffmpeg", "ffprobe"]
        
        for tool in tools {
            if let bundledPath = getBundledExecutablePath(tool) {
                await removeQuarantineFlag(from: bundledPath)
                await makeExecutable(bundledPath)
            }
        }
    }

    private func getBundledExecutablePath(_ tool: String) -> String? {
        // Check různé možné lokace v bundle
        let possiblePaths = [
            Bundle.main.resourcePath?.appending("/\(tool)"),
            Bundle.main.resourcePath?.appending("/Executables/\(tool)"),
            Bundle.main.path(forResource: tool, ofType: nil)
        ]
        
        for path in possiblePaths {
            if let path = path, FileManager.default.fileExists(atPath: path) {
                print("📍 Found bundled \(tool) at: \(path)")
                return path
            }
        }
        
        print("❌ Bundled \(tool) not found")
        return nil
    }

    private func removeQuarantineFlag(from path: String) async {
        print("🏷️ Removing quarantine flag from: \(path)")
        
        let result = await runShellCommand("/usr/bin/xattr", arguments: ["-d", "com.apple.quarantine", path])
        
        if result.isEmpty || result.contains("No such xattr") {
            print("✅ Quarantine flag removed or wasn't present")
        } else if result.contains("Operation not permitted") {
            print("⚠️ Permission denied - trying alternative method")
            // Zkus smazat všechny extended attributes
            _ = await runShellCommand("/usr/bin/xattr", arguments: ["-c", path])
        } else {
            print("⚠️ xattr result: \(result)")
        }
    }

    private func makeExecutable(_ path: String) async {
        print("🔧 Making executable: \(path)")
        
        let result = await runShellCommand("/bin/chmod", arguments: ["+x", path])
        if result.isEmpty {
            print("✅ Made executable")
        } else {
            print("⚠️ chmod result: \(result)")
        }
    }
    
    private func runShellCommand(_ command: String, arguments: [String]) async -> String {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
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
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    continuation.resume(returning: output)
                } catch {
                    print("❌ Failed to run command: \(error)")
                    continuation.resume(returning: "Error: \(error)")
                }
            }
        }
    }
}

// MARK: - Error Types

enum DependencyError: LocalizedError {
    case homebrewNotFound
    case homebrewInstallationFailed
    case installationFailed(description: String, exitCode: Int32, output: String)
    case installationIncomplete(missing: [String])
    case permissionDenied(String)  // <- Přidejte String parameter
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
        case .permissionDenied(let message):  // <- Aktualizujte error description
            return "Permission denied: \(message)"
        case .networkError:
            return "Network error during installation. Please check your internet connection."
        case .unsupportedSystem:
            return "Unsupported system configuration"
        }
    }
}

extension DependenciesManager {
    // Přidejte do DependenciesManager.swift

    func performDiagnostics() -> String {
        var report = "🔍 WallMotion Dependencies Diagnostics\n"
        report += "=====================================\n\n"
        
        // 1. Environment info
        report += "📱 Environment:\n"
        report += "• App Bundle: \(Bundle.main.bundlePath)\n"
        report += "• Sandbox: \(isSandboxed() ? "✅ Enabled" : "❌ Disabled")\n"
        report += "• PATH: \(ProcessInfo.processInfo.environment["PATH"] ?? "Not set")\n\n"
        
        // 2. Tool detection
        report += "🔧 Tool Detection:\n"
        for tool in ["brew", "ffmpeg", "yt-dlp"] {
            let path = findExecutablePath(for: tool)
            let status = path != nil ? "✅" : "❌"
            report += "• \(tool): \(status) \(path ?? "Not found")\n"
        }
        report += "\n"
        
        // 3. Homebrew specific
        report += "🍺 Homebrew Analysis:\n"
        let homebrewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        for path in homebrewPaths {
            let exists = FileManager.default.fileExists(atPath: path)
            let executable = FileManager.default.isExecutableFile(atPath: path)
            report += "• \(path): \(exists ? "✅ Exists" : "❌ Missing") \(executable ? "✅ Executable" : "")\n"
        }
        
        // 4. Permissions test
        report += "\n🔒 Permissions Test:\n"
        let testPaths = ["/opt/homebrew", "/usr/local", "/Library/Application Support/com.apple.idleassetsd"]
        for path in testPaths {
            let readable = FileManager.default.isReadableFile(atPath: path)
            report += "• \(path): \(readable ? "✅ Readable" : "❌ Not readable")\n"
        }
        
        return report
    }

    private func isSandboxed() -> Bool {
        let sandboxPath = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"]
        return sandboxPath != nil
    }

    func testExternalProcess() async -> (success: Bool, output: String) {
        // Test jestli můžeme spustit external process
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/uname")
                task.arguments = ["-a"]
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    let success = task.terminationStatus == 0
                    let result = success ? "✅ External process test: SUCCESS\n\(output)" : "❌ External process test: FAILED"
                    
                    continuation.resume(returning: (success, result))
                } catch {
                    continuation.resume(returning: (false, "❌ External process test: ERROR - \(error)"))
                }
            }
        }
    }
}
