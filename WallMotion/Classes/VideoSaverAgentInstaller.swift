//
//  VideoSaverAgentInstaller.swift
//  WallMotion
//
//  Enhanced VideoSaver agent installer with quarantine handling
//

import Foundation
import Cocoa

class VideoSaverAgentInstaller {
    private let launchAgentsPath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/LaunchAgents"
    private let plistName = "com.wallmotion.videosaver.plist"
    private let agentName = "VideoSaver"
    
    func installVideoSaverAgent() async -> Bool {
        print("🚀 Installing VideoSaverAgent with quarantine handling...")
        // Přidej na začátek installVideoSaverAgent() metody:
        print("🔍 VideoSaver debug info:")
        print("🔍 Bundle path: \(Bundle.main.bundlePath)")
        print("🔍 ExecutableManager videoSaverPath: \(ExecutableManager.shared.videoSaverPath?.path ?? "nil")")

        if let resourcePath = Bundle.main.resourcePath {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("📁 Files in Resources: \(files)")
                
                let videoSaverPath = "\(resourcePath)/VideoSaver"
                let exists = FileManager.default.fileExists(atPath: videoSaverPath)
                let isExecutable = FileManager.default.isExecutableFile(atPath: videoSaverPath)
                print("🔍 VideoSaver at \(videoSaverPath) - exists: \(exists), executable: \(isExecutable)")
            } catch {
                print("❌ Error listing Resources: \(error)")
            }
        }
        
        // 1. Vytvoř LaunchAgents adresář
        do {
            try FileManager.default.createDirectory(atPath: launchAgentsPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ Failed to create LaunchAgents directory: \(error)")
            return false
        }
        
        // 2. Najdi VideoSaverAgent pomocí ExecutableManager
        guard let videoSaverURL = ExecutableManager.shared.videoSaverPath else {
            print("❌ VideoSaverAgent not found in app bundle")
            return await handleMissingVideoSaver()
        }
        
        // 3. Zkopíruj agent do lokální cache bez quarantine
        guard let cachedAgentPath = await copyAgentToCache(from: videoSaverURL) else {
            return false
        }
        
        // 4. Vytvoř a nainstaluj plist
        if !createLaunchAgentPlist(agentPath: cachedAgentPath) {
            return false
        }
        
        // 5. Load launch agent
        if !(await loadLaunchAgent()) {
            return await showManualInstallationInstructions()
        }
        
        print("✅ VideoSaverAgent installed and running")
        return true
    }
    
    // MARK: - Enhanced Installation Methods
    
    private func copyAgentToCache(from sourceURL: URL) async -> String? {
        // Vytvoř cache directory v uživatelském prostoru
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WallMotion")
            .appendingPathComponent("Agents")
        
        do {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create cache directory: \(error)")
            return nil
        }
        
        let targetURL = cacheDir.appendingPathComponent("VideoSaver")
        
        // Smaž starý agent pokud existuje
        if FileManager.default.fileExists(atPath: targetURL.path) {
            do {
                try FileManager.default.removeItem(at: targetURL)
            } catch {
                print("⚠️ Failed to remove old cached agent: \(error)")
            }
        }
        
        // Zkopíruj agent
        do {
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            
            // Nastav executable permissions
            let attributes = [FileAttributeKey.posixPermissions: 0o755]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: targetURL.path)
            
            // **KLÍČOVÉ: Remove quarantine flag**
            await removeQuarantineFlag(from: targetURL.path)
            
            print("✅ VideoSaverAgent copied to cache: \(targetURL.path)")
            return targetURL.path
            
        } catch {
            print("❌ Failed to copy agent to cache: \(error)")
            return nil
        }
    }
    
    private func removeQuarantineFlag(from path: String) async {
        print("🔓 Removing quarantine flag from VideoSaver...")
        
        // Použij xattr pro odstranění quarantine flag
        let result = await runShellCommand("/usr/bin/xattr", arguments: ["-d", "com.apple.quarantine", path])
        
        if result.contains("No such xattr") || result.isEmpty {
            print("✅ Quarantine flag removed (or wasn't present)")
        } else if result.contains("Operation not permitted") {
            print("⚠️ Permission denied removing quarantine - will try manual approach")
        } else {
            print("⚠️ xattr result: \(result)")
        }
        
        // Alternative: remove all extended attributes
        _ = await runShellCommand("/usr/bin/xattr", arguments: ["-c", path])
    }
    
    private func createLaunchAgentPlist(agentPath: String) -> Bool {
        let plistPath = "\(launchAgentsPath)/\(plistName)"
        
        // Enhanced plist with better error handling
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.wallmotion.videosaver</string>
            
            <key>ProgramArguments</key>
            <array>
                <string>\(agentPath)</string>
            </array>
            
            <key>RunAtLoad</key>
            <true/>
            
            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
                <key>Crashed</key>
                <true/>
            </dict>
            
            <key>StandardOutPath</key>
            <string>/tmp/wallmotion-videosaver.log</string>
            
            <key>StandardErrorPath</key>
            <string>/tmp/wallmotion-videosaver-error.log</string>
            
            <key>ProcessType</key>
            <string>Background</string>
            
            <key>LowPriorityIO</key>
            <true/>
            
            <key>ThrottleInterval</key>
            <integer>5</integer>
            
            <key>ExitTimeOut</key>
            <integer>30</integer>
        </dict>
        </plist>
        """
        
        do {
            try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
            print("✅ Launch agent plist created at: \(plistPath)")
            return true
        } catch {
            print("❌ Failed to create plist: \(error)")
            return false
        }
    }
    
    private func loadLaunchAgent() async -> Bool {
        let plistPath = "\(launchAgentsPath)/\(plistName)"
        
        print("🔄 Loading launch agent...")
        
        // Unload pokud už běží
        _ = await runShellCommand("/bin/launchctl", arguments: ["unload", plistPath])
        
        // Load nový agent
        let loadResult = await runShellCommand("/bin/launchctl", arguments: ["load", plistPath])
        
        if loadResult.contains("Operation not permitted") {
            print("❌ Operation not permitted - macOS security restrictions")
            return false
        } else if loadResult.contains("service already loaded") {
            print("✅ Service already loaded")
        } else if !loadResult.isEmpty && loadResult.contains("error") {
            print("❌ Failed to load launch agent: \(loadResult)")
            return false
        }
        
        // Malé zpoždění
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Spusť agent
        let startResult = await runShellCommand("/bin/launchctl", arguments: ["start", "com.wallmotion.videosaver"])
        
        if !startResult.isEmpty && startResult.contains("error") {
            print("⚠️ Start result: \(startResult)")
        }
        
        // Ověř že běží
        let isRunning = await isVideoSaverAgentRunning()
        return isRunning
    }
    
    // MARK: - Fallback and Manual Installation
    
    private func handleMissingVideoSaver() async -> Bool {
        print("📁 VideoSaver not found in bundle, debugging...")
        
        if let resourcePath = Bundle.main.resourcePath {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("📁 Files in bundle Resources: \(files)")
            } catch {
                print("❌ Error reading bundle: \(error)")
            }
        }
        
        return await showManualInstallationInstructions()
    }
    
    @MainActor
    private func showManualInstallationInstructions() async -> Bool {
        let alert = NSAlert()
        alert.messageText = "VideoSaver Installation"
        alert.informativeText = """
        Due to macOS security restrictions, VideoSaver installation requires manual approval.
        
        The VideoSaver has been prepared but needs your permission to run.
        
        Options:
        1. Try automatic installation again (may require admin password)
        2. Install manually via Terminal (most reliable)
        3. Skip VideoSaver installation for now
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Try Again")
        alert.addButton(withTitle: "Manual Instructions")
        alert.addButton(withTitle: "Skip")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Try again with enhanced permissions
            return await installWithEnhancedPermissions()
        case .alertSecondButtonReturn:
            showDetailedManualInstructions()
            return false
        default:
            return false
        }
    }
    
    private func installWithEnhancedPermissions() async -> Bool {
        // Zkus instalaci s osascript pro admin permissions
        let script = """
        do shell script "launchctl load '\(launchAgentsPath)/\(plistName)'" with administrator privileges
        """
        
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            print("❌ AppleScript error: \(error)")
            return false
        }
        
        return await isVideoSaverAgentRunning()
    }
    
    @MainActor
    private func showDetailedManualInstructions() {
        let alert = NSAlert()
        alert.messageText = "Manual VideoSaver Installation"
        alert.informativeText = """
        To install VideoSaver manually:
        
        1. Open Terminal
        2. Run these commands:
        
        launchctl load ~/Library/LaunchAgents/com.wallmotion.videosaver.plist
        launchctl start com.wallmotion.videosaver
        
        3. Check if running:
        launchctl list | grep wallmotion
        """
        alert.addButton(withTitle: "Copy Commands")
        alert.addButton(withTitle: "OK")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let commands = """
            launchctl load ~/Library/LaunchAgents/com.wallmotion.videosaver.plist
            launchctl start com.wallmotion.videosaver
            """
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(commands, forType: .string)
        }
    }
    
    // MARK: - Status and Utilities
    
    func isVideoSaverAgentRunning() async -> Bool {
        let result = await runShellCommand("/bin/launchctl", arguments: ["list", "com.wallmotion.videosaver"])
        let isRunning = !result.contains("Could not find service")
        
        if isRunning {
            print("✅ VideoSaverAgent is running")
        } else {
            print("⚠️ VideoSaverAgent is not running")
        }
        
        return isRunning
    }
    
    func uninstallVideoSaverAgent() async -> Bool {
        let plistPath = "\(launchAgentsPath)/\(plistName)"
        
        // Stop and unload agent
        _ = await runShellCommand("/bin/launchctl", arguments: ["stop", "com.wallmotion.videosaver"])
        _ = await runShellCommand("/bin/launchctl", arguments: ["unload", plistPath])
        
        // Remove plist
        do {
            try FileManager.default.removeItem(atPath: plistPath)
            print("✅ VideoSaverAgent uninstalled")
            return true
        } catch {
            print("❌ Failed to uninstall agent: \(error)")
            return false
        }
    }
    
    // MARK: - Shell Command Helper
    
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
                    let result = String(data: data, encoding: .utf8) ?? ""
                    
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(returning: "Failed to run \(command): \(error)")
                }
            }
        }
    }
}
