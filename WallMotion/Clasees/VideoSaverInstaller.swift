//
//  VideoSaverInstaller.swift
//  WallMotion
//
//  Created by Šimon Filípek on 16.07.2025.
//


import Foundation
import Cocoa

class VideoSaverInstaller {
    private let screenSaverPath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/Screen Savers"
    private let videoSaverName = "VideoSaver.saver"
    
    func installVideoSaver() -> Bool {
        print("🚀 Installing VideoSaver screen saver...")
        
        // 1. Vytvoř Screen Savers adresář pokud neexistuje
        do {
            try FileManager.default.createDirectory(atPath: screenSaverPath, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create Screen Savers directory: \(error)")
            return false
        }
        
        // 2. Najdi VideoSaver.saver v app bundle
        guard let bundlePath = Bundle.main.path(forResource: "VideoSaver", ofType: "saver") else {
            print("❌ VideoSaver.saver not found in app bundle")
            return false
        }
        
        // 3. Zkopíruj do Screen Savers
        let targetPath = "\(screenSaverPath)/\(videoSaverName)"
        
        // Smaž starý pokud existuje
        if FileManager.default.fileExists(atPath: targetPath) {
            do {
                try FileManager.default.removeItem(atPath: targetPath)
                print("🗑️ Removed old VideoSaver")
            } catch {
                print("⚠️ Failed to remove old VideoSaver: \(error)")
            }
        }
        
        // Zkopíruj nový
        do {
            try FileManager.default.copyItem(atPath: bundlePath, toPath: targetPath)
            print("✅ VideoSaver installed successfully")
            return true
        } catch {
            print("❌ Failed to install VideoSaver: \(error)")
            return false
        }
    }
    
    func isVideoSaverInstalled() -> Bool {
        let targetPath = "\(screenSaverPath)/\(videoSaverName)"
        return FileManager.default.fileExists(atPath: targetPath)
    }
    
    func uninstallVideoSaver() -> Bool {
        let targetPath = "\(screenSaverPath)/\(videoSaverName)"
        
        guard FileManager.default.fileExists(atPath: targetPath) else {
            print("VideoSaver not installed")
            return true
        }
        
        do {
            try FileManager.default.removeItem(atPath: targetPath)
            print("✅ VideoSaver uninstalled")
            return true
        } catch {
            print("❌ Failed to uninstall VideoSaver: \(error)")
            return false
        }
    }
}
