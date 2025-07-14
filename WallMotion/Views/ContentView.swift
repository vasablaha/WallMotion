//
//  ContentView.swift
//  WallMotion
//
//  Created by Václav Blaha on 13.07.2025.
//

import SwiftUI
import AVKit
import Foundation
import Combine

struct ContentView: View {
    @StateObject private var wallpaperManager = WallpaperManager()
    @State private var selectedVideoURL: URL?
    @State private var selectedLibraryVideo: WallpaperVideo?
    @State private var isProcessing = false
    @State private var progress: Double = 0.0
    @State private var statusMessage = "Choose a video to get started"
    @State private var showingFilePicker = false
    @State private var showingSuccess = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
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
    }
    
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
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            headerSection
            
            Divider()
                .padding(.horizontal)
            
            // Categories section - HIDDEN for now
            // categorySection
            
            // Custom video upload section
            customUploadSection
            
            Divider()
                .padding(.horizontal)
            
            detectionSection
            
            Spacer()
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
            Image(systemName: "desktopcomputer")
                .font(.system(size: 50, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("WallMotion")
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            
            Text("Premium Live Wallpapers")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 30)
    }
    
    // MARK: - Categories section (hidden)
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Categories")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(VideoCategory.allCases.filter { $0 != .custom }, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: wallpaperManager.selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            wallpaperManager.selectedCategory = category
                            selectedLibraryVideo = nil
                            selectedVideoURL = nil
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Custom Upload Section (main focus now)
    private var customUploadSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Upload Video")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            Button(action: { showingFilePicker = true }) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Choose Video File")
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text("MP4, MOV, or other video formats")
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
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            
            // Show selected video info
            if let selectedURL = selectedVideoURL {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Video Selected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    Text(selectedURL.lastPathComponent)
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
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            if wallpaperManager.selectedCategory == .custom {
                customVideoView
            } else {
                videoLibraryView
            }
            
            Divider()
            
            actionSection
        }
        .background(Color.clear)
    }
    
    private var videoLibraryView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 20)
            ], spacing: 20) {
                ForEach(wallpaperManager.filteredVideos) { video in
                    VideoCard(
                        video: video,
                        isSelected: selectedLibraryVideo?.id == video.id
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedLibraryVideo = video
                            selectedVideoURL = nil
                            statusMessage = "Selected: \(video.name)"
                        }
                    }
                }
            }
            .padding(30)
        }
        .background(Color.clear)
    }
    
    private var customVideoView: some View {
        VStack {
            Spacer()
            
            if let url = selectedVideoURL {
                CustomVideoCard(videoURL: url)
            } else {
                EmptyCustomVideoView {
                    showingFilePicker = true
                }
            }
            
            Spacer()
        }
        .padding(30)
    }
    
    private var actionSection: some View {
        VStack(spacing: 0) {
            // Progress section (only show when processing)
            if isProcessing {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "gear")
                            .rotationEffect(.degrees(360))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isProcessing)
                        
                        Text("Processing wallpaper replacement...")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(y: 1.5)
                        
                        HStack {
                            Text(statusMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(progress * 100))%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.blue.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 30)
                .padding(.top, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Status message (only when not processing)
            if !isProcessing && !statusMessage.isEmpty && statusMessage != "Choose a video to get started" {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: statusMessage.contains("Wallpaper replaced") ? "checkmark.circle.fill" :
                                           statusMessage.contains("Failed") ? "xmark.circle.fill" : "info.circle.fill")
                            .foregroundColor(statusMessage.contains("Wallpaper replaced") ? .green :
                                           statusMessage.contains("Failed") ? .red : .blue)
                        
                        Text(statusMessage)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Action button section
            VStack(spacing: 16) {
                // Ready indicator
                if isReadyToReplace && !isProcessing {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Ready to replace wallpaper")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                    .transition(.opacity)
                }
                
                // Main action button
                Button(action: replaceWallpaper) {
                    HStack(spacing: 12) {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Text(isProcessing ? "Processing..." : "Replace Wallpaper")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: isReadyToReplace && !isProcessing ?
                                        [.blue, .purple] : [.gray.opacity(0.4), .gray.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(
                                color: isReadyToReplace && !isProcessing ? .blue.opacity(0.4) : .clear,
                                radius: 12, x: 0, y: 6
                            )
                    )
                    .scaleEffect(isReadyToReplace && !isProcessing ? 1.0 : 0.96)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isReadyToReplace)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!isReadyToReplace || isProcessing)
                .padding(.horizontal, 30)
                
                // Instruction text
                if !isReadyToReplace && !isProcessing {
                    Text(getInstructionText())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 30)
            .background(.ultraThinMaterial)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isProcessing)
    }
    
    private func getInstructionText() -> String {
        let hasVideo = selectedVideoURL != nil || selectedLibraryVideo != nil
        let hasWallpaper = !wallpaperManager.detectedWallpaper.isEmpty &&
                          !wallpaperManager.detectedWallpaper.contains("No wallpaper") &&
                          !wallpaperManager.detectedWallpaper.contains("Error")
        
        if !hasWallpaper {
            return "Set a video wallpaper in System Settings first"
        } else if !hasVideo {
            return "Choose a video file to upload"
        } else {
            return "Ready to replace your wallpaper"
        }
    }
    
    private var isReadyToReplace: Bool {
        let hasVideo = selectedVideoURL != nil || selectedLibraryVideo != nil
        let hasWallpaper = !wallpaperManager.detectedWallpaper.isEmpty &&
                          !wallpaperManager.detectedWallpaper.contains("No wallpaper") &&
                          !wallpaperManager.detectedWallpaper.contains("Error")
        return hasVideo && hasWallpaper
    }
    
    private func handleVideoSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                selectedVideoURL = url
                selectedLibraryVideo = nil
                wallpaperManager.selectedCategory = .custom
                print("Custom video selected: \(url.path)")
                statusMessage = "Custom video ready: \(url.lastPathComponent)"
            }
        case .failure(let error):
            print("Video selection error: \(error)")
            statusMessage = "Failed to select video"
        }
    }
    
    private func replaceWallpaper() {
        var videoURL: URL?
        
        if let selectedLibrary = selectedLibraryVideo {
            // For library videos, we'd need to get the actual file URL
            // For now, we'll simulate with a bundle resource path
            if let bundleURL = Bundle.main.url(forResource: selectedLibrary.fileName.replacingOccurrences(of: ".mov", with: ""), withExtension: "mov") {
                videoURL = bundleURL
            } else {
                statusMessage = "Library video not found"
                return
            }
        } else if let customURL = selectedVideoURL {
            videoURL = customURL
        }
        
        guard let finalURL = videoURL else {
            statusMessage = "No video selected"
            return
        }
        
        print("Starting premium wallpaper replacement...")
        print("Detected wallpaper: \(wallpaperManager.detectedWallpaper)")
        print("Video source: \(finalURL.path)")
        
        isProcessing = true
        progress = 0.0
        
        Task {
            await wallpaperManager.replaceWallpaper(videoURL: finalURL) { progressValue, message in
                DispatchQueue.main.async {
                    self.progress = progressValue
                    self.statusMessage = message
                    
                    if progressValue >= 1.0 {
                        self.isProcessing = false
                        self.showingSuccess = true
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
