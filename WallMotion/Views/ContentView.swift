//
//  ContentView.swift (Updated with Tutorial)
//  WallMotion
//
//  Created by Václav Blaha on 13.07.2025.
//

import SwiftUI
import AVKit
import Foundation
import Combine

enum MainViewType {
    case welcome
    case youtubeImport
    case tutorial
}

struct ContentView: View {
    @StateObject private var wallpaperManager = WallpaperManager()
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var deviceManager = DeviceManager.shared
    @StateObject private var videoSaverManager = VideoSaverManager()
    
    @State private var selectedVideoURL: URL?
    @State private var selectedLibraryVideo: WallpaperVideo?
    @State private var selectedYouTubeVideo: URL?
    @State private var isProcessing = false
    @State private var progress: Double = 0.0
    @State private var statusMessage = "Choose a video to get started"
    @State private var showingFilePicker = false
    @State private var showingSuccess = false
    @State private var showingCategories = true
    @State private var showingLoginSheet = false
    @State private var isPerformingInitialAuth = true
    @State private var currentView: MainViewType = .welcome
    @State private var showingFirstTimeTutorial = false
    @State private var showingHelpTutorial = false

    
    @Environment(\.colorScheme) private var colorScheme
    
    // UserDefaults key for tracking first launch
    private let hasSeenTutorialKey = "HasSeenTutorial"
    
    var body: some View {
        Group {
            if isPerformingInitialAuth {
                // Initial loading screen
                initialLoadingView
            } else if authManager.isAuthenticated && authManager.hasValidLicense {
                // Main app interface
                mainAppView
            } else {
                // License required
                noLicenseView
            }
        }
        .task {
            await performInitialAuthentication()
        }
        .sheet(isPresented: $showingLoginSheet) {
            LoginView()
                .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showingFirstTimeTutorial) {
            TutorialView(onComplete: {
                showingFirstTimeTutorial = false
                UserDefaults.standard.set(true, forKey: hasSeenTutorialKey)
            })
            .frame(width: 700, height: 800)
            .interactiveDismissDisabled(false)
        }
    }
    
    // MARK: - Initial Loading View
    
    private var initialLoadingView: some View {
        VStack(spacing: 20) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
            
            Text("WallMotion")
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            
            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 20)
            
            Text("Checking authentication...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
    }
    
    // MARK: - No License View
    
    private var noLicenseView: some View {
        VStack(spacing: 30) {
            VStack(spacing: 20) {
                Image(systemName: "key.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                VStack(spacing: 12) {
                    Text("License Required")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if !authManager.isAuthenticated {
                        Text("Please sign in to your WallMotion account to continue using the app.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    } else {
                        Text("You need a valid license to use WallMotion. Please purchase a license from our website.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            }
            
            VStack(spacing: 16) {
                if !authManager.isAuthenticated {
                    // Sign In Button
                    Button(action: {
                        showingLoginSheet = true
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle")
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                } else {
                    // Purchase License Button
                    Button(action: {
                        if let url = URL(string: "https://wallmotion.eu/") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "cart")
                            Text("Purchase License")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    // Sign Out Button - pro přihlášení na jiný účet
                    Button(action: {
                        authManager.signOut()
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.minus")
                            Text("Sign Out & Use Different Account")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    // Current user info
                    if let user = authManager.user {
                        VStack(spacing: 4) {
                            Text("Currently signed in as:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                        }
                        .padding(.top, 8)
                    }
                }
                
                // Quit App Button
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit App")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient)
    }
    
    // MARK: - Main App View
    
    private var mainAppView: some View {
        NavigationView {
            sidebarView
            mainContentView
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .frame(minWidth: 1200, minHeight: 800)
        .background(backgroundGradient)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.movie, .quickTimeMovie, .mpeg4Movie],
            allowsMultipleSelection: false
        ) { result in
            handleVideoSelection(result)
        }
        .alert("Success!", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text("Wallpaper replaced successfully! Check System Settings to see your new wallpaper.")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Account Settings") {
                        showingLoginSheet = true
                    }
                    
                    Divider()
                    
                    Button("Show Tutorial") {
                        showingFirstTimeTutorial = true
                    }
                    
                    Divider()
                    
                    Button("Purchase Additional License") {
                        if let url = URL(string: "https://wallmotion.eu/profile") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    
                    Divider()
                    
                    Button("Sign Out") {
                        authManager.signOut()
                    }
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                }
            }
        }
        .onAppear {
            checkForFirstTimeTutorial()
        }
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        Group {
            switch currentView {
            case .welcome:
                welcomeView
            case .youtubeImport:
                YouTubeImportView { videoURL in
                    selectedYouTubeVideo = videoURL
                    selectedVideoURL = nil
                    selectedLibraryVideo = nil
                    statusMessage = "YouTube video ready: \(videoURL.lastPathComponent)"
                    currentView = .welcome
                }
            case .tutorial:
                TutorialView(onComplete: {
                    currentView = .welcome
                    showingHelpTutorial = false
                })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: 40) {
            // Header with icon and title
            VStack(spacing: 20) {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 80, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 12) {
                    Text("Welcome to WallMotion")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Choose a video file or import from YouTube to create your custom live wallpaper.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                HStack(spacing: 20) {
                    Button("Choose Video File") {
                        showingFilePicker = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Import from YouTube") {
                        currentView = .youtubeImport
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            
            // Show selected video preview if available
            if let videoURL = selectedVideoURL {
                VideoPreviewCard(
                    videoURL: videoURL,
                    isProcessing: isProcessing,
                    progress: progress
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                if !isProcessing {
                    Button("Set as Wallpaper") {
                        replaceWallpaper(with: videoURL)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else if let youtubeURL = selectedYouTubeVideo {
                VideoPreviewCard(
                    videoURL: youtubeURL,
                    isProcessing: isProcessing,
                    progress: progress
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                if !isProcessing {
                    Button("Set as Wallpaper") {
                        replaceWallpaper(with: youtubeURL)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Background Gradient
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark ?
                [Color.black.opacity(0.8), Color.blue.opacity(0.1)] :
                [Color.white, Color.blue.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Sidebar View
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            headerSection
            
            Divider()
                .padding(.horizontal)
            
            // Main custom video upload section (priority)
            customUploadSection
            
            Divider()
                .padding(.horizontal)
            
            // YouTube import section
            youtubeImportSection
            
            Divider()
                .padding(.horizontal)
            
            detectionSection
            
            Divider()
                .padding(.horizontal)
            
            VideoSaverSectionView(videoSaverManager: videoSaverManager)
            Divider()
                .padding(.horizontal)
            
            // Help & Tutorial section
            helpSection
            
            Spacer()
            
            // User info footer
            userInfoFooter
        }
        .frame(minWidth: 300, maxWidth: 350)
        .background(sidebarBackground)
    }
    
    private var sidebarBackground: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
    }
    
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
            
            Text("WallMotion")
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            
            
        }
        .padding(.vertical, 30)
    }
    
    // MARK: - Custom Upload Section
    
    private var customUploadSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Custom Upload")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal)
            
            Button(action: {
                // OPRAVA: Vždy přepnout na welcome view když uživatel chce nahrát soubor
                currentView = .welcome
                showingFilePicker = true
            }) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Choose Video File")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("MP4, MOV supported")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            
            // Show selected custom video info
            if let videoURL = selectedVideoURL {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Video Selected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    Text(videoURL.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .padding(.leading, 20)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - YouTube Import Section
    
    private var youtubeImportSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("YouTube Import")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal)
            
            Button(action: {
                currentView = .youtubeImport
            }) {
                HStack {
                    Image(systemName: "play.rectangle.on.rectangle.fill")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import from YouTube")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Paste URL to download")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            
            // Show selected YouTube video info
            if let youtubeURL = selectedYouTubeVideo {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("YouTube Video Ready")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    Text(youtubeURL.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .padding(.leading, 20)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Detection Section
    
    private var detectionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Current Wallpaper")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        wallpaperManager.detectCurrentWallpaper()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            
            DetectionCard(detectedWallpaper: wallpaperManager.detectedWallpaper)
                .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Help Section
    
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Help & Support")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal)
            
            VStack(spacing: 8) {
                // Tutorial button
                Button(action: {
                    if currentView == .tutorial {
                        currentView = .welcome
                    } else {
                        currentView = .tutorial
                    }
                }) {
                    HStack {
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Setup Tutorial")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Step-by-step guide")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: currentView == .tutorial ? "chevron.down" : "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - User Info Footer
    
    private var userInfoFooter: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.horizontal)
            
            if let user = authManager.user {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        Text(user.email)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: deviceManager.isRegistered ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(deviceManager.isRegistered ? .green : .orange)
                            .font(.caption2)
                        
                        Text(deviceManager.isRegistered ? "Device Registered" : "Device Not Registered")
                            .font(.caption2)
                            .foregroundColor(deviceManager.isRegistered ? .green : .orange)
                        
                        Spacer()
                        
                        if let licensesCount = user.licensesCount {
                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(.purple)
                                        .font(.caption2)
                                    
                                    Text("License: \(user.licenseType.uppercased())")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Methods
    
    private func performInitialAuthentication() async {
        print("🚀 Performing initial authentication check...")
        
        // Small delay to show loading screen
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let isAuthenticated = await authManager.performAppLaunchAuthentication()
        
        await MainActor.run {
            isPerformingInitialAuth = false
            
            if !isAuthenticated {
                // Show login if needed
                print("⚠️ Authentication required")
            } else {
                print("✅ Authentication successful")
            }
        }
    }

    
    
    private func checkForFirstTimeTutorial() {
        let hasSeenTutorial = UserDefaults.standard.bool(forKey: hasSeenTutorialKey)
        if !hasSeenTutorial {
            Task { @MainActor in
                showingFirstTimeTutorial = true
            }
        }
    }
    
    private func handleVideoSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedVideoURL = url
            selectedLibraryVideo = nil
            selectedYouTubeVideo = nil
            statusMessage = "Video selected: \(url.lastPathComponent)"
            
        case .failure(let error):
            statusMessage = "Error selecting video: \(error.localizedDescription)"
        }
    }
    
    private func replaceWallpaper(with videoURL: URL) {
        Task {
            await MainActor.run {
                isProcessing = true
                progress = 0.0
            }
            
            await wallpaperManager.replaceWallpaper(videoURL: videoURL) { newProgress, message in
                Task { @MainActor in
                    progress = newProgress
                    statusMessage = message
                    
                    if newProgress >= 1.0 {
                        isProcessing = false
                        showingSuccess = true
                        
                        // Update last seen after successful wallpaper change
                        if let token = authManager.getCurrentAuthToken() {
                            await deviceManager.updateLastSeen(authToken: token)
                        }
                    }
                }
            }
        }
    }
}

