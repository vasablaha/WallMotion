//
//  WallMotionApp.swift
//  WallMotion - Optimized for single initialization
//

import SwiftUI

@main
struct WallMotionApp: App {
    // MARK: - Shared Managers (Singleton pattern)
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var deviceManager = DeviceManager.shared
    @StateObject private var dependenciesManager = DependenciesManager.shared // Make it singleton
    @StateObject private var wallpaperManager = WallpaperManager.shared // Make it singleton
    
    // MARK: - App State
    @State private var hasInitialized = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(deviceManager)
                .environmentObject(dependenciesManager)
                .environmentObject(wallpaperManager)
                .onAppear {
                    performOneTimeInitialization()
                }
        }
        .windowStyle(DefaultWindowStyle())
        .windowResizability(.contentSize)
        .commands {
            // Custom menu commands
            CommandGroup(replacing: .appInfo) {
                Button("About WallMotion") {
                    showAboutWindow()
                }
            }
            
            CommandGroup(after: .appInfo) {
                Divider()
                
                Button("Sign In...") {
                    Task {
                        await authManager.authenticateWithWeb()
                    }
                }
                .disabled(authManager.isAuthenticated)
                
                Button("Sign Out") {
                    authManager.signOut()
                }
                .disabled(!authManager.isAuthenticated)
                
                Divider()
                
                Button("Account Settings") {
                    if let url = URL(string: "https://wallmotion.eu/profile") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .disabled(!authManager.isAuthenticated)
                
                Button("Purchase License") {
                    if let url = URL(string: "https://wallmotion.eu") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            
            CommandGroup(after: .help) {
                Button("WallMotion Support") {
                    if let url = URL(string: "https://wallmotion.eu/support") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("Check for Updates") {
                    checkForUpdates()
                }
            }
        }
    }
    
    // MARK: - Single Point of Initialization
    
    private func performOneTimeInitialization() {
        // Prevent multiple initialization runs
        guard !hasInitialized else {
            print("⏭️ App already initialized, skipping...")
            return
        }
        
        hasInitialized = true
        print("🚀 Starting WallMotion initialization (one-time)...")
        
        setupAppearance()
        
        Task {
            await initializeApp()
        }
    }
    
    private func initializeApp() async {
        print("🔧 Phase 1: Initializing bundled tools...")
        await initializeBundledTools()
        
        print("🔐 Phase 2: Performing authentication check...")
        _ = await authManager.performAppLaunchAuthentication()
        
        print("✅ WallMotion initialization complete!")
    }
    
    // MARK: - Bundle Tools Initialization (Single Run)
    
    private func initializeBundledTools() async {
        print("🛠️ Initializing bundled tools...")
        
        // Use DependenciesManager to initialize bundled executables
        await dependenciesManager.initializeBundledExecutables()
        
        // Check final status
        let status = dependenciesManager.checkDependencies()
        
        await MainActor.run {
            print("📊 Bundle tools final status:")
            print("   yt-dlp: \(status.ytdlp ? "✅" : "❌")")
            print("   ffmpeg: \(status.ffmpeg ? "✅" : "❌")")
            print("   ffprobe: \(status.ffprobe ? "✅" : "❌")")
            
            if status.allAvailable {
                print("✅ All bundled tools ready for use")
            } else {
                print("⚠️ Some bundled tools need attention:")
                for missing in status.missing {
                    print("   - Missing: \(missing)")
                }
            }
        }
    }
    
    // MARK: - App Setup
    
    private func setupAppearance() {
        // Configure app appearance
        NSWindow.allowsAutomaticWindowTabbing = false
        print("🎨 App appearance configured")
    }
    
    private func showAboutWindow() {
        let alert = NSAlert()
        alert.messageText = "WallMotion"
        alert.informativeText = """
        Version \(getAppVersion())
        Premium Live Wallpapers for macOS
        
        © 2025 Tapp Studio
        All rights reserved.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Visit Website")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://wallmotion.eu") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func checkForUpdates() {
        // TODO: Implement update checking
        let alert = NSAlert()
        alert.messageText = "Check for Updates"
        alert.informativeText = "You have the latest version of WallMotion."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - App Delegate for handling URL schemes

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        // Handle custom URL scheme (wallmotion://)
        for url in urls {
            if url.scheme == "wallmotion" {
                print("📱 Received URL scheme: \(url)")
                
                // Handle authentication callback
                if url.host == "auth" {
                    // This will be handled by AuthenticationManager
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AuthCallbackReceived"),
                        object: url
                    )
                }
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 WallMotion launched")
        setupNotificationObservers()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 WallMotion terminating")
        cleanupBeforeTermination()
    }
    
    private func setupNotificationObservers() {
        // Observe authentication callbacks
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AuthCallbackReceived"),
            object: nil,
            queue: .main
        ) { notification in
            if let url = notification.object as? URL {
                print("🔐 Processing auth callback: \(url)")
                // The URL will be processed by ASWebAuthenticationSession
            }
        }
    }
    
    private func cleanupBeforeTermination() {
        // Perform any necessary cleanup
        let authManager = AuthenticationManager.shared
        let deviceManager = DeviceManager.shared
        
        if authManager.isAuthenticated, let token = authManager.getCurrentAuthToken() {
            Task {
                await deviceManager.updateLastSeen(authToken: token)
            }
        }
    }
}
