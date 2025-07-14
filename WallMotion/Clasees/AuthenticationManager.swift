//
//  AuthenticationManager.swift
//  WallMotion
//
//  Authentication and user management
//

import Foundation
import Combine
import AuthenticationServices

class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var authError: String?
    @Published var isLoading = false
    
    private let networkManager = NetworkManager.shared
    private let keychain = KeychainManager.shared
    private let deviceManager = DeviceManager.shared
    
    // Store the presentation context provider as instance variable
    private let contextProvider = WebAuthenticationContextProvider()
    private var authSession: ASWebAuthenticationSession?
    
    // AWS Cognito configuration
    private let cognitoEndpoint = "https://wallmotion.eu/api" // Updated to new domain
    
    private init() {
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication Status
    
    func checkAuthenticationStatus() {
        print("🔐 Checking authentication status...")
        
        // Check if we have stored auth token and user info
        if let token = keychain.getAuthToken(),
           let user = keychain.getUserInfo() {
            self.user = user
            self.isAuthenticated = true
            print("✅ User authenticated from keychain: \(user.email)")
            
            // Auto-register device if not already registered
            if !deviceManager.isRegistered {
                Task {
                    await deviceManager.registerDevice(authToken: token)
                }
            } else {
                // Update last seen
                Task {
                    await deviceManager.updateLastSeen(authToken: token)
                }
            }
        } else {
            self.isAuthenticated = false
            print("⚠️ User not authenticated")
        }
    }
    
    // MARK: - Web Authentication
    
    @MainActor
    func authenticateWithWeb() async {
        isLoading = true
        self.authError = nil
        
        print("🌐 Starting web authentication...")
        
        // Open web authentication
        guard let authURL = URL(string: "https://wallmotion.eu/login?app=macos") else {
            self.authError = "Invalid authentication URL"
            isLoading = false
            return
        }
        
        print("🔗 Auth URL: \(authURL)")
        print("📱 Callback scheme: wallmotion")
        
        // Create and store session
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "wallmotion"
        ) { [weak self] callbackURL, error in
            Task {
                await self?.handleAuthCallback(callbackURL: callbackURL, error: error)
            }
        }
        
        guard let session = authSession else {
            self.authError = "Failed to create authentication session"
            isLoading = false
            return
        }
        
        // Debug: Check if we have windows
        print("🪟 Available windows: \(NSApplication.shared.windows.count)")
        print("🪟 Main window exists: \(NSApplication.shared.mainWindow != nil)")
        
        // Set presentation context provider before starting
        session.presentationContextProvider = contextProvider
        session.prefersEphemeralWebBrowserSession = false
        
        print("✅ Presentation context provider set")
        print("🚀 Starting authentication session...")
        
        // Start session
        let started = session.start()
        print("📊 Session start result: \(started)")
        
        if !started {
            self.authError = "Failed to start authentication session"
            isLoading = false
            authSession = nil
        }
    }
    
    private func handleAuthCallback(callbackURL: URL?, error: Error?) async {
        defer {
            Task { @MainActor in
                isLoading = false
                authSession = nil // Clean up session
            }
        }
        
        if let error = error {
            print("❌ Auth callback error: \(error)")
            
            // Handle specific ASWebAuthenticationSession errors
            if let sessionError = error as? ASWebAuthenticationSessionError {
                switch sessionError.code {
                case .canceledLogin:
                    await MainActor.run {
                        self.authError = "Authentication was cancelled"
                    }
                    return
                case .presentationContextNotProvided:
                    await MainActor.run {
                        self.authError = "Authentication window could not be displayed"
                    }
                    return
                case .presentationContextInvalid:
                    await MainActor.run {
                        self.authError = "Authentication context is invalid"
                    }
                    return
                @unknown default:
                    await MainActor.run {
                        self.authError = "Authentication failed: \(sessionError.localizedDescription)"
                    }
                    return
                }
            } else {
                await MainActor.run {
                    self.authError = "Authentication failed: \(error.localizedDescription)"
                }
                return
            }
        }
        
        guard let callbackURL = callbackURL else {
            print("❌ No callback URL received")
            await MainActor.run {
                self.authError = "Authentication cancelled"
            }
            return
        }
        
        print("🔐 Auth callback received: \(callbackURL)")
        
        // Parse the callback URL to extract auth token
        if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) {
            // Look for token in query parameters or fragment
            var authToken: String?
            
            if let queryItems = components.queryItems {
                authToken = queryItems.first(where: { $0.name == "token" })?.value
            }
            
            if authToken == nil, let fragment = components.fragment {
                let fragmentComponents = fragment.components(separatedBy: "&")
                for component in fragmentComponents {
                    let parts = component.components(separatedBy: "=")
                    if parts.count == 2 && parts[0] == "token" {
                        authToken = parts[1]
                        break
                    }
                }
            }
            
            if let token = authToken {
                print("✅ Auth token received: \(token.prefix(20))...")
                
                // Decode the token and get user info
                do {
                    try await authenticateWithToken(token)
                } catch {
                    print("❌ Failed to authenticate with token: \(error)")
                    await MainActor.run {
                        self.authError = "Authentication failed: \(error.localizedDescription)"
                    }
                }
            } else {
                print("❌ No auth token found in callback URL")
                await MainActor.run {
                    self.authError = "No authentication token received"
                }
            }
        } else {
            print("❌ Failed to parse callback URL")
            await MainActor.run {
                self.authError = "Invalid callback URL"
            }
        }
    }
    
    private func authenticateWithToken(_ token: String) async throws {
        print("🔐 Authenticating with token...")
        
        // Get user info from server
        let userResponse = try await networkManager.getUserInfo(authToken: token)
        let user = userResponse.user
        
        // Save to keychain
        keychain.saveAuthToken(token)
        keychain.saveUserInfo(user)
        
        await MainActor.run {
            self.user = user
            self.isAuthenticated = true
            print("✅ User authenticated: \(user.email)")
        }
        
        // Register device automatically
        await deviceManager.registerDevice(authToken: token)
    }
    
    // MARK: - License Validation
    
    func validateLicense() async -> Bool {
        print("🔍 Validating license...")
        
        let fingerprint = deviceManager.generateDeviceFingerprint()
        let bundleId = Bundle.main.bundleIdentifier ?? "tapp-studio.WallMotion"
        let version = deviceManager.getAppVersion() ?? "1.0"
        
        do {
            let response = try await networkManager.validateLicense(
                fingerprint: fingerprint,
                bundleId: bundleId,
                version: version
            )
            
            if response.valid {
                print("✅ License valid")
                return true
            } else {
                print("❌ License invalid: \(response.reason ?? "Unknown reason")")
                
                await MainActor.run {
                    self.authError = response.reason ?? "License validation failed"
                }
                return false
            }
            
        } catch {
            print("❌ License validation error: \(error)")
            await MainActor.run {
                self.authError = "License validation failed: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        print("🚪 Signing out...")
        
        keychain.clearAllData()
        deviceManager.unregisterDevice()
        
        user = nil
        isAuthenticated = false
        self.authError = nil
        
        print("✅ Signed out successfully")
    }
    
    // MARK: - App Launch Authentication Flow
    
    func performAppLaunchAuthentication() async -> Bool {
        print("🚀 Performing app launch authentication...")
        
        // First check if we have valid stored authentication
        if isAuthenticated {
            // Validate the license
            let isLicenseValid = await validateLicense()
            if isLicenseValid {
                print("✅ App launch authentication successful")
                return true
            } else {
                // License invalid, need to re-authenticate
                signOut()
            }
        }
        
        // Show authentication UI
        await MainActor.run {
            self.authError = "Please sign in to continue using WallMotion"
        }
        
        return false
    }
}

// MARK: - Web Authentication Context Provider

class WebAuthenticationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        print("🎯 presentationAnchor called")
        
        // Debug available windows
        let windows = NSApplication.shared.windows
        print("📱 Available windows count: \(windows.count)")
        
        for (index, window) in windows.enumerated() {
            print("  Window \(index): \(window.title), visible: \(window.isVisible), key: \(window.isKeyWindow)")
        }
        
        // Try main window first
        if let mainWindow = NSApplication.shared.mainWindow {
            print("✅ Using main window: \(mainWindow.title)")
            return mainWindow
        }
        
        // Try key window
        if let keyWindow = NSApplication.shared.keyWindow {
            print("✅ Using key window: \(keyWindow.title)")
            return keyWindow
        }
        
        // Try first visible window
        if let firstWindow = windows.first(where: { $0.isVisible }) {
            print("✅ Using first visible window: \(firstWindow.title)")
            return firstWindow
        }
        
        // Use any window
        if let anyWindow = windows.first {
            print("✅ Using any available window: \(anyWindow.title)")
            return anyWindow
        }
        
        print("❌ No window found!")
        fatalError("No window available for authentication presentation")
    }
}

// MARK: - Authentication Extensions

extension AuthenticationManager {
    
    // Convenience method to get current auth token
    func getCurrentAuthToken() -> String? {
        return keychain.getAuthToken()
    }
    
    // Check if user has valid license
    var hasValidLicense: Bool {
        guard let user = user else { return false }
        return user.licenseType != "NONE" && (user.licensesCount ?? 0) > 0
    }
    
    // Get license count
    var licenseCount: Int {
        return user?.licensesCount ?? 0
    }
}
