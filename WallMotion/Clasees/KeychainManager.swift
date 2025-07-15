//
//  KeychainManager.swift
//  WallMotion
//
//  Secure storage for authentication tokens and device info
//

import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let serviceName = "WallMotion"
    private let deviceInfoKey = "DeviceInfo"
    private let authTokenKey = "AuthToken"
    private let userInfoKey = "UserInfo"
    private let service = "eu.wallmotion.app"

    private init() {}
    
    // MARK: - Generic Keychain Operations
    
    private func save(data: Data, key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    private func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Device Info
    
    func saveDeviceInfo(_ device: Device) {
        do {
            let encoder = JSONEncoder()
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                try container.encode(iso8601Formatter.string(from: date))
            }
            
            let data = try encoder.encode(device)
            let success = save(data: data, key: deviceInfoKey)
            
            if success {
                print("✅ Device info saved to keychain")
            } else {
                print("❌ Failed to save device info to keychain")
            }
        } catch {
            print("❌ Error encoding device info: \(error)")
        }
    }
    
    func getDeviceInfo() -> Device? {
        guard let data = load(key: deviceInfoKey) else {
            print("⚠️ No device info found in keychain")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
                }
            }
            
            let device = try decoder.decode(Device.self, from: data)
            print("✅ Device info loaded from keychain")
            return device
        } catch {
            print("❌ Error decoding device info: \(error)")
            return nil
        }
    }
    
    func deleteDeviceInfo() {
        let success = delete(key: deviceInfoKey)
        if success {
            print("✅ Device info deleted from keychain")
        } else {
            print("❌ Failed to delete device info from keychain")
        }
    }
    
    // MARK: - Auth Token (for future use)
    
    func saveAuthToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        let success = save(data: data, key: authTokenKey)
        
        if success {
            print("✅ Auth token saved to keychain")
        } else {
            print("❌ Failed to save auth token to keychain")
        }
    }
    
    func getAuthToken() -> String? {
        guard let data = load(key: authTokenKey),
              let token = String(data: data, encoding: .utf8) else {
            print("⚠️ No auth token found in keychain")
            return nil
        }
        
        print("✅ Auth token loaded from keychain")
        return token
    }
    
    func deleteAuthToken() {
        let success = delete(key: authTokenKey)
        if success {
            print("✅ Auth token deleted from keychain")
        } else {
            print("❌ Failed to delete auth token from keychain")
        }
    }
    
    // MARK: - User Info (for future use)
    
    func saveUserInfo(_ user: User) {
        do {
            let encoder = JSONEncoder()
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                try container.encode(iso8601Formatter.string(from: date))
            }
            
            let data = try encoder.encode(user)
            let success = save(data: data, key: userInfoKey)
            
            if success {
                print("✅ User info saved to keychain")
            } else {
                print("❌ Failed to save user info to keychain")
            }
        } catch {
            print("❌ Error encoding user info: \(error)")
        }
    }
    
    func getUserInfo() -> User? {
        guard let data = load(key: userInfoKey) else {
            print("⚠️ No user info found in keychain")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
                }
            }
            
            let user = try decoder.decode(User.self, from: data)
            print("✅ User info loaded from keychain")
            return user
        } catch {
            print("❌ Error decoding user info: \(error)")
            return nil
        }
    }
    
    func deleteUserInfo() {
        let success = delete(key: userInfoKey)
        if success {
            print("✅ User info deleted from keychain")
        } else {
            print("❌ Failed to delete user info from keychain")
        }
    }
    
    // MARK: - Clear All Data
    
    func clearAllData() {
        deleteDeviceInfo()
        deleteAuthToken()
        deleteUserInfo()
        print("🗑️ All keychain data cleared")
    }
}
