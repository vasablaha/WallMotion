//
//  SimpleVideoSaverAgentInstaller.swift
//  WallMotion
//
//  Zjednodušený installer bez ExecutableManager závislosti
//

import Foundation
import Cocoa

class SimpleVideoSaverAgentInstaller {
    private let launchAgentsPath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/LaunchAgents"
    private let plistName = "com.wallmotion.videosaver.plist"
    private let agentName = "VideoSaver"
    
    // MARK: - Public Methods
    
    func installVideoSaverAgent() async -> Bool {
        print("🚀 Installing VideoSaver Agent...")
        
        // 1. Vytvoř LaunchAgents adresář
        do {
            try FileManager.default.createDirectory(atPath: launchAgentsPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ Failed to create LaunchAgents directory: \(error)")
            return false
        }
        
        // 2. Najdi VideoSaver v bundle
        guard let videoSaverURL = findVideoSaverInBundle() else {
            print("❌ VideoSaver not found in app bundle")
            return await showManualInstallationInstructions()
        }
        
        // 3. Zkopíruj agent do cache
        guard let cachedAgentPath = await copyAgentToCache(from: videoSaverURL) else {
            return false
        }
        
        // 4. Vytvoř plist
        if !createLaunchAgentPlist(agentPath: cachedAgentPath) {
            return false
        }
        
        // 5. Spusť agent
        if !(await loadLaunchAgent()) {
            return await showManualInstallationInstructions()
        }
        
        print("✅ VideoSaver Agent installed and running")
        return true
    }
    
    func uninstallVideoSaverAgent() async -> Bool {
        print("🛑 Uninstalling VideoSaver Agent...")
        
        let plistPath = "\(launchAgentsPath)/\(plistName)"
        
        // 1. Zastavit agent
        _ = await runShellCommand("/bin/launchctl", arguments: ["unload", plistPath])
        
        // 2. Smazat plist
        do {
            try FileManager.default.removeItem(atPath: plistPath)
            print("✅ VideoSaver Agent plist removed")
        } catch {
            print("⚠️ Failed to remove plist: \(error)")
        }
        
        // 3. Smazat cached agent
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WallMotion")
            .appendingPathComponent("Agents")
        
        do {
            try FileManager.default.removeItem(at: cacheDir)
            print("✅ VideoSaver Agent cache cleaned")
        } catch {
            print("⚠️ Failed to clean cache: \(error)")
        }
        
        return true
    }
    
    func isVideoSaverAgentRunning() async -> Bool {
        let result = await runShellCommand("/bin/launchctl", arguments: ["list", "com.wallmotion.videosaver"])
        return !result.isEmpty && !result.contains("Could not find service")
    }
    
    // MARK: - Private Methods
    
    private func findVideoSaverInBundle() -> URL? {
        print("🔍 Looking for VideoSaver in app bundle...")
        
        // Zkus různé možné lokace
        let possiblePaths = [
            Bundle.main.resourceURL?.appendingPathComponent("VideoSaver"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/VideoSaver"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/VideoSaver")
        ]
        
        for path in possiblePaths {
            guard let url = path else { continue }
            
            print("🔍 Checking: \(url.path)")
            
            if FileManager.default.fileExists(atPath: url.path) {
                let isExecutable = FileManager.default.isExecutableFile(atPath: url.path)
                print("✅ Found VideoSaver at: \(url.path) (executable: \(isExecutable))")
                return url
            }
        }
        
        // Debug: vypsat obsah Resources
        if let resourcePath = Bundle.main.resourcePath {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("📁 Files in Resources: \(files)")
            } catch {
                print("❌ Error listing Resources: \(error)")
            }
        }
        
        print("❌ VideoSaver executable not found in bundle")
        return nil
    }
    
    private func copyAgentToCache(from sourceURL: URL) async -> String? {
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
        
        // Smaž starý agent
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
            
            // Odstraň quarantine flag
            await removeQuarantineFlag(from: targetURL.path)
            
            print("✅ VideoSaver copied to cache: \(targetURL.path)")
            return targetURL.path
            
        } catch {
            print("❌ Failed to copy agent to cache: \(error)")
            return nil
        }
    }
    
    private func removeQuarantineFlag(from path: String) async {
        print("🔓 Removing quarantine flag from VideoSaver...")
        
        let commands = [
            ["xattr", "-d", "com.apple.quarantine", path],
            ["xattr", "-c", path]
        ]
        
        for command in commands {
            let result = await runShellCommand(command[0], arguments: Array(command.dropFirst()))
            if !result.isEmpty {
                print("🔓 Quarantine removal result: \(result)")
            }
        }
    }
    
    private func createLaunchAgentPlist(agentPath: String) -> Bool {
        let plistPath = "\(launchAgentsPath)/\(plistName)"
        
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
            <key>KeepAlive</key>
            <true/>
            <key>RunAtLoad</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/tmp/wallmotion-videosaver.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/wallmotion-videosaver.log</string>
        </dict>
        </plist>
        """
        
        do {
            try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
            print("✅ VideoSaver plist created: \(plistPath)")
            return true
        } catch {
            print("❌ Failed to create plist: \(error)")
            return false
        }
    }
    
    private func loadLaunchAgent() async -> Bool {
        let plistPath = "\(launchAgentsPath)/\(plistName)"
        
        print("🚀 Loading VideoSaver Agent...")
        
        // Load agent
        let loadResult = await runShellCommand("/bin/launchctl", arguments: ["load", plistPath])
        if !loadResult.isEmpty && loadResult.contains("error") {
            print("⚠️ Load result: \(loadResult)")
        }
        
        // Krátká pauza
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
            print("⚠️ Sleep interrupted: \(error)")
        }
        
        // Start agent
        let startResult = await runShellCommand("/bin/launchctl", arguments: ["start", "com.wallmotion.videosaver"])
        if !startResult.isEmpty && startResult.contains("error") {
            print("⚠️ Start result: \(startResult)")
        }
        
        // Ověř že běží
        let isRunning = await isVideoSaverAgentRunning()
        return isRunning
    }
    
    private func runShellCommand(_ command: String, arguments: [String]) async -> String {
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: command)
            task.arguments = arguments
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                task.waitUntilExit()
                continuation.resume(returning: output)
            } catch {
                continuation.resume(returning: "Error: \(error)")
            }
        }
    }
    
    @MainActor
    private func showManualInstallationInstructions() async -> Bool {
        let alert = NSAlert()
        alert.messageText = "VideoSaver Installation"
        alert.informativeText = """
        VideoSaver couldn't be installed automatically due to macOS security restrictions.
        
        You can:
        1. Try again (may require admin password)
        2. Install manually via Terminal
        3. Skip VideoSaver for now
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Try Again")
        alert.addButton(withTitle: "Manual Instructions")
        alert.addButton(withTitle: "Skip")
        
        let response = await MainActor.run {
            alert.runModal()
        }
        
        switch response {
        case .alertFirstButtonReturn:
            return await installVideoSaverAgent()
        case .alertSecondButtonReturn:
            await showDetailedManualInstructions()
            return false
        default:
            return false
        }
    }
    
    @MainActor
    private func showDetailedManualInstructions() async {
        let alert = NSAlert()
        alert.messageText = "Manual VideoSaver Installation"
        alert.informativeText = """
        To install VideoSaver manually:
        
        1. Open Terminal
        2. Run these commands:
        
        launchctl load ~/Library/LaunchAgents/com.wallmotion.videosaver.plist
        launchctl start com.wallmotion.videosaver
        
        3. VideoSaver should now be running in the background
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        await MainActor.run {
            _ = alert.runModal()
        }
    }
}
