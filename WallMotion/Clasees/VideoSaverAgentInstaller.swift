// VideoSaverAgentInstaller.swift - Kompletní async oprava

import Foundation
import Cocoa

class VideoSaverAgentInstaller {
    private let launchAgentsPath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/LaunchAgents"
    private let plistName = "com.wallmotion.videosaver.plist"
    private let agentName = "VideoSaver"
    
    // ✅ ZMĚNĚNO NA ASYNC
    func installVideoSaverAgent() async -> Bool {
        print("🚀 Installing VideoSaverAgent...")
        
        // 1. Vytvoř LaunchAgents adresář
        do {
            try FileManager.default.createDirectory(atPath: launchAgentsPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ Failed to create LaunchAgents directory: \(error)")
            return false
        }
        
        // 2. Najdi VideoSaverAgent v app bundle
        guard let bundlePath = Bundle.main.path(forResource: agentName, ofType: nil) else {
            print("❌ VideoSaverAgent not found in app bundle")
            
            // Debug: seznam všech souborů v Resources
            if let resourcePath = Bundle.main.resourcePath {
                do {
                    let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    print("📁 Files in bundle: \(files)")
                } catch {
                    print("❌ Error reading bundle: \(error)")
                }
            }
            
            return false
        }
        
        // 3. Cesta kam zkopírovat agent (do WallMotion app bundle)
        let targetAgentPath = "\(Bundle.main.bundlePath)/Contents/Resources/VideoSaverAgent"
        
        // Smaž starý agent pokud existuje
        if FileManager.default.fileExists(atPath: targetAgentPath) {
            do {
                try FileManager.default.removeItem(atPath: targetAgentPath)
            } catch {
                print("⚠️ Failed to remove old agent: \(error)")
            }
        }
        
        // Zkopíruj agent na finální místo
        do {
            try FileManager.default.copyItem(atPath: bundlePath, toPath: targetAgentPath)
            
            // Nastav executable permissions
            let attributes = [FileAttributeKey.posixPermissions: 0o755]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: targetAgentPath)
            
            print("✅ VideoSaverAgent copied and made executable")
        } catch {
            print("❌ Failed to install agent: \(error)")
            return false
        }
        
        // 4. Vytvoř a nainstaluj plist
        if !createLaunchAgentPlist(agentPath: targetAgentPath) {
            return false
        }
        
        // 5. Load launch agent
        if !(await loadLaunchAgent()) {
            return false
        }
        
        print("✅ VideoSaverAgent installed and running")
        return true
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
            
            <key>RunAtLoad</key>
            <true/>
            
            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
            </dict>
            
            <key>StandardOutPath</key>
            <string>/tmp/videosaver.log</string>
            
            <key>StandardErrorPath</key>
            <string>/tmp/videosaver_error.log</string>
            
            <key>ProcessType</key>
            <string>Background</string>
            
            <key>LowPriorityIO</key>
            <true/>
            
            <key>ThrottleInterval</key>
            <integer>10</integer>
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
    
    // ✅ ZMĚNĚNO NA ASYNC
    private func loadLaunchAgent() async -> Bool {
        let plistPath = "\(launchAgentsPath)/\(plistName)"
        
        // Unload pokud už běží
        _ = await runShellCommand("launchctl", arguments: ["unload", plistPath])
        
        // Load nový agent
        let result = await runShellCommand("launchctl", arguments: ["load", plistPath])
        if result.contains("error") || result.contains("failed") {
            print("❌ Failed to load launch agent: \(result)")
            return false
        }
        
        // Spusť agent hned
        _ = await runShellCommand("launchctl", arguments: ["start", "com.wallmotion.videosaver"])
        
        print("✅ Launch agent loaded and started")
        return true
    }
    
    // ✅ ZMĚNĚNO NA ASYNC
    func isVideoSaverAgentRunning() async -> Bool {
        let result = await runShellCommand("launchctl", arguments: ["list", "com.wallmotion.videosaver"])
        let isRunning = !result.contains("Could not find service")
        
        if isRunning {
            print("✅ VideoSaverAgent is running")
        } else {
            print("⚠️ VideoSaverAgent is not running")
        }
        
        return isRunning
    }
    
    // ✅ ZMĚNĚNO NA ASYNC
    func uninstallVideoSaverAgent() async -> Bool {
        let plistPath = "\(launchAgentsPath)/\(plistName)"
        
        // Stop agent
        _ = await runShellCommand("launchctl", arguments: ["stop", "com.wallmotion.videosaver"])
        
        // Unload agent
        _ = await runShellCommand("launchctl", arguments: ["unload", plistPath])
        
        // Smaž plist
        do {
            try FileManager.default.removeItem(atPath: plistPath)
            print("✅ VideoSaverAgent uninstalled")
            return true
        } catch {
            print("❌ Failed to uninstall agent: \(error)")
            return false
        }
    }
    
    // ✅ ASYNC VERZE runShellCommand
    private func runShellCommand(_ command: String, arguments: [String]) async -> String {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let task = Process()
                
                if command.hasPrefix("/") {
                    task.executableURL = URL(fileURLWithPath: command)
                    task.arguments = arguments
                } else {
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    task.arguments = [command] + arguments
                }
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe
                
                do {
                    try task.run()
                    task.waitUntilExit()  // ✅ Teď je na background thread
                    
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
