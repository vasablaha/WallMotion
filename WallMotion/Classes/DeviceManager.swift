//
//  DeviceManager.swift
//  WallMotion
//
//  Created by Šimon Filípek on 14.07.2025.
//


//
//  DeviceManager.swift
//  WallMotion
//
//  Device registration and management
//

import Foundation
import IOKit
import Combine
import CommonCrypto


class DeviceManager: ObservableObject {
    static let shared = DeviceManager()
    
    @Published var isRegistered = false
    @Published var deviceInfo: Device?
    @Published var registrationError: String?
    
    private let networkManager = NetworkManager.shared
    private let keychain = KeychainManager.shared
    
    private init() {
        checkRegistrationStatus()
    }
    
    // MARK: - Device Fingerprinting
    
    func generateDeviceFingerprint() -> String {
        let components = [
            getSystemUUID(),
            getSerialNumber(),
            getMacAddress(),
            getPlatformUUID()
        ].compactMap { $0 }
        
        let combined = components.joined(separator: "-")
        return combined.sha256()
    }
    
    func logoutDevice(authToken: String) async {
        let fingerprint = generateDeviceFingerprint()
        
        do {
            let response = try await networkManager.logoutDevice(
                fingerprint: fingerprint,
                authToken: authToken
            )
            
            if response.success {
                print("✅ Device logged out on server")
            } else {
                print("⚠️ Failed to logout device on server")
            }
        } catch {
            print("⚠️ Error logging out device: \(error)")
        }
    }
    
    private func getSystemUUID() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(platformExpert) }
        
        guard platformExpert != 0 else { return nil }
        
        return IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String
    }
    
    private func getSerialNumber() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(platformExpert) }
        
        guard platformExpert != 0 else { return nil }
        
        return IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformSerialNumberKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String
    }
    
    private func getMacAddress() -> String? {
        var macAddress: String?
        
        let task = Process()
        // ✅ OPRAVA: Use executableURL
        task.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        task.arguments = ["en0"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("❌ Failed to get MAC address: \(error)")
            return nil
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("ether") {
                    let components = line.components(separatedBy: .whitespaces)
                    if let etherIndex = components.firstIndex(of: "ether"), etherIndex + 1 < components.count {
                        macAddress = components[etherIndex + 1]
                        break
                    }
                }
            }
        }
        
        return macAddress
    }
    
    private func getPlatformUUID() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(platformExpert) }
        
        guard platformExpert != 0 else { return nil }
        
        return IORegistryEntryCreateCFProperty(
            platformExpert,
            "IOPlatformUUID" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String
    }
    
    // MARK: - System Information
    
    func getMacModel() -> String? {
        let task = Process()
        // ✅ OPRAVA: Use executableURL
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
        task.arguments = ["-n", "hw.model"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("❌ Failed to get Mac model: \(error)")
            return nil
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func getMacOSVersion() -> String? {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    func getAppVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    func getDeviceName() -> String {
        return Host.current().localizedName ?? "Mac"
    }
    
    func registerDevice(authToken: String) async {
        print("🔧 Starting device registration...")
        
        await MainActor.run {
            registrationError = nil
        }
        
        let fingerprint = generateDeviceFingerprint()
        let deviceName = getDeviceName()
        let macModel = getMacModel()
        let macosVersion = getMacOSVersion()
        let appVersion = getAppVersion()
        
        print("📱 Device info:")
        print("  - Name: \(deviceName)")
        print("  - Fingerprint: \(fingerprint.prefix(20))...")
        print("  - Model: \(macModel ?? "Unknown")")
        print("  - macOS: \(macosVersion ?? "Unknown")")
        print("  - App Version: \(appVersion ?? "Unknown")")
        
        do {
            let response = try await networkManager.registerDevice(
                fingerprint: fingerprint,
                name: deviceName,
                macModel: macModel,
                macosVersion: macosVersion,
                appVersion: appVersion,
                authToken: authToken
            )
            
            if response.success, let device = response.device {
                // Save device info to keychain
                keychain.saveDeviceInfo(device)
                
                await MainActor.run {
                    self.deviceInfo = device
                    self.isRegistered = true
                    print("✅ Device registered successfully: \(device.name)")
                }
            } else {
                await MainActor.run {
                    self.registrationError = "Registration failed: Invalid response"
                }
            }
            
        } catch {
            print("❌ Device registration failed: \(error)")
            await MainActor.run {
                self.registrationError = error.localizedDescription
            }
        }
    }
    
    func updateLastSeen(authToken: String) async {
        guard let device = deviceInfo else { return }
        
        // We'll use the license validation endpoint to update last seen
        let fingerprint = generateDeviceFingerprint()
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let version = getAppVersion() ?? "1.0"
        
        do {
            _ = try await networkManager.validateLicense(
                fingerprint: fingerprint,
                bundleId: bundleId,
                version: version
            )
            print("📡 Last seen updated")
        } catch {
            print("⚠️ Failed to update last seen: \(error)")
        }
    }
    
    func unregisterDevice() {
        keychain.deleteDeviceInfo()
        deviceInfo = nil
        isRegistered = false
        print("🗑️ Device unregistered locally")
    }
    func unregisterDeviceLocally() {
        // POZOR: Pouze lokální cleanup, neodstraňujeme ze serveru
        keychain.deleteDeviceInfo()
        deviceInfo = nil
        isRegistered = false
        print("🗑️ Device unregistered locally only")
    }

}

// MARK: - String Extension for SHA256

extension String {
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.bindMemory(to: UInt8.self).baseAddress, CC_LONG(data.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}


extension DeviceManager {
    
    // MARK: - Device Display Name Methods
    
    /// Vrátí název zařízení pro zobrazení - buď deviceDisplayName nebo name
    func getDisplayDeviceName() -> String {
        return deviceInfo?.displayName ?? getDeviceName()
    }
    
    /// Aktualizace checkRegistrationStatus metody pro podporu deviceDisplayName
    func checkRegistrationStatus() {
        // Check if device is already registered (stored in keychain)
        if let deviceData = keychain.getDeviceInfo() {
            self.deviceInfo = deviceData
            self.isRegistered = true
            print("✅ Device already registered: \(deviceData.displayName)")
        } else {
            self.isRegistered = false
            print("⚠️ Device not registered")
        }
    }
}
// Import CommonCrypto for SHA256
