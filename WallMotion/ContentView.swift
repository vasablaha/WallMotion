import SwiftUI
import AVKit
import Foundation
import Combine

// MARK: - Video Library Models
struct WallpaperVideo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: VideoCategory
    let duration: String
    let resolution: String
    let thumbnailName: String
    let fileName: String
    let description: String
    
    var isCustom: Bool { fileName.isEmpty }
}

enum VideoCategory: String, CaseIterable {
    case nature = "Nature"
    case abstract = "Abstract"
    case ocean = "Ocean"
    case space = "Space"
    case minimal = "Minimal"
    case custom = "Custom"
    
    var icon: String {
        switch self {
        case .nature: return "leaf.fill"
        case .abstract: return "circle.hexagongrid.fill"
        case .ocean: return "water.waves"
        case .space: return "moon.stars.fill"
        case .minimal: return "circle.fill"
        case .custom: return "folder.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .nature: return .green
        case .abstract: return .purple
        case .ocean: return .blue
        case .space: return .indigo
        case .minimal: return .gray
        case .custom: return .orange
        }
    }
}

// MARK: - Smart WallpaperManager with Video Library
class WallpaperManager: ObservableObject {
    @Published var availableWallpapers: [String] = []
    @Published var detectedWallpaper: String = ""
    @Published var videoLibrary: [WallpaperVideo] = []
    @Published var selectedCategory: VideoCategory = .custom // Changed to custom as default since categories are hidden
    
    private let wallpaperPath = "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"
    
    init() {
        print("WallpaperManager: Premium version initialized")
        loadVideoLibrary()
        detectCurrentWallpaper()
    }
    
    func loadVideoLibrary() {
        videoLibrary = [
            // Nature Category
            WallpaperVideo(
                name: "Forest Rain",
                category: .nature,
                duration: "2:30",
                resolution: "4K",
                thumbnailName: "forest_rain_thumb",
                fileName: "forest_rain.mov",
                description: "Gentle rain falling through green forest canopy"
            ),
            WallpaperVideo(
                name: "Mountain Mist",
                category: .nature,
                duration: "1:45",
                resolution: "4K",
                thumbnailName: "mountain_mist_thumb",
                fileName: "mountain_mist.mov",
                description: "Misty clouds rolling over mountain peaks"
            ),
            WallpaperVideo(
                name: "Autumn Leaves",
                category: .nature,
                duration: "3:00",
                resolution: "4K",
                thumbnailName: "autumn_leaves_thumb",
                fileName: "autumn_leaves.mov",
                description: "Golden leaves gently falling in autumn breeze"
            ),
            
            // Ocean Category
            WallpaperVideo(
                name: "Deep Blue",
                category: .ocean,
                duration: "2:15",
                resolution: "4K",
                thumbnailName: "deep_blue_thumb",
                fileName: "deep_blue.mov",
                description: "Mesmerizing deep ocean waves"
            ),
            WallpaperVideo(
                name: "Coral Garden",
                category: .ocean,
                duration: "4:00",
                resolution: "4K",
                thumbnailName: "coral_garden_thumb",
                fileName: "coral_garden.mov",
                description: "Vibrant coral reef with tropical fish"
            ),
            
            // Abstract Category
            WallpaperVideo(
                name: "Fluid Motion",
                category: .abstract,
                duration: "1:30",
                resolution: "4K",
                thumbnailName: "fluid_motion_thumb",
                fileName: "fluid_motion.mov",
                description: "Smooth flowing abstract patterns"
            ),
            WallpaperVideo(
                name: "Neon Dreams",
                category: .abstract,
                duration: "2:45",
                resolution: "4K",
                thumbnailName: "neon_dreams_thumb",
                fileName: "neon_dreams.mov",
                description: "Colorful neon lights and geometric shapes"
            ),
            
            // Space Category
            WallpaperVideo(
                name: "Galaxy Spiral",
                category: .space,
                duration: "3:30",
                resolution: "4K",
                thumbnailName: "galaxy_spiral_thumb",
                fileName: "galaxy_spiral.mov",
                description: "Stunning spiral galaxy rotation"
            ),
            WallpaperVideo(
                name: "Nebula",
                category: .space,
                duration: "2:00",
                resolution: "4K",
                thumbnailName: "nebula_thumb",
                fileName: "nebula.mov",
                description: "Colorful cosmic nebula clouds"
            ),
            
            // Minimal Category
            WallpaperVideo(
                name: "Clean Waves",
                category: .minimal,
                duration: "1:20",
                resolution: "4K",
                thumbnailName: "clean_waves_thumb",
                fileName: "clean_waves.mov",
                description: "Simple, elegant wave animation"
            )
        ]
        
        print("Loaded \(videoLibrary.count) videos in library")
    }
    
    var filteredVideos: [WallpaperVideo] {
        if selectedCategory == .custom {
            return []
        }
        return videoLibrary.filter { $0.category == selectedCategory }
    }
    
    func detectCurrentWallpaper() {
        print("Detecting currently set wallpaper...")
        print("Scanning: \(wallpaperPath)")
        
        guard FileManager.default.fileExists(atPath: wallpaperPath) else {
            print("Wallpaper folder not found: \(wallpaperPath)")
            detectedWallpaper = "No wallpaper detected - please set one first"
            availableWallpapers = []
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: wallpaperPath)
            let movFiles = files.filter { $0.hasSuffix(".mov") && !$0.contains(".backup") }
            
            print("Found \(movFiles.count) .mov files in folder")
            
            if movFiles.isEmpty {
                print("No .mov files found")
                detectedWallpaper = "No wallpapers downloaded - set one first"
                availableWallpapers = []
                return
            }
            
            var newestFile: String = ""
            var newestDate: Date = Date.distantPast
            
            for file in movFiles {
                let filePath = "\(wallpaperPath)/\(file)"
                let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
                
                if let modDate = attributes[.modificationDate] as? Date {
                    if modDate > newestDate {
                        newestDate = modDate
                        newestFile = file
                    }
                }
            }
            
            if !newestFile.isEmpty {
                let wallpaperName = newestFile.replacingOccurrences(of: ".mov", with: "")
                detectedWallpaper = wallpaperName
                availableWallpapers = [wallpaperName]
                print("Detected current wallpaper: \(wallpaperName)")
            } else {
                detectedWallpaper = "Detection failed"
                availableWallpapers = []
            }
            
        } catch {
            print("Error scanning wallpaper folder: \(error.localizedDescription)")
            detectedWallpaper = "Error: \(error.localizedDescription)"
            availableWallpapers = []
        }
    }
    
    func replaceWallpaper(
        videoURL: URL,
        progressCallback: @escaping (Double, String) -> Void
    ) async {
        
        print("Starting smart wallpaper replacement...")
        print("Source video: \(videoURL.path)")
        
        progressCallback(0.1, "Detecting current wallpaper...")
        
        await MainActor.run {
            detectCurrentWallpaper()
        }
        
        guard !detectedWallpaper.isEmpty && !detectedWallpaper.contains("No wallpaper") && !detectedWallpaper.contains("Error") else {
            progressCallback(0.0, "No wallpaper detected. Please set a video wallpaper in System Settings first!")
            return
        }
        
        let targetFileName = "\(detectedWallpaper).mov"
        let targetPath = "\(wallpaperPath)/\(targetFileName)"
        
        progressCallback(0.2, "Preparing video...")
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempVideoPath = tempDir.appendingPathComponent("wallpaper_temp.mov").path
        let backupPath = "\(targetPath).backup.\(Int(Date().timeIntervalSince1970))"
        
        do {
            try FileManager.default.copyItem(atPath: videoURL.path, toPath: tempVideoPath)
            print("Video copied to temp location")
        } catch {
            print("Failed to copy to temp: \(error)")
            progressCallback(0.0, "Failed to prepare video")
            return
        }
        
        progressCallback(0.4, "Requesting admin access (ONE TIME ONLY)...")
        
        guard await executeAllCommands(tempVideoPath: tempVideoPath, targetPath: targetPath, backupPath: backupPath, progressCallback: progressCallback) else {
            try? FileManager.default.removeItem(atPath: tempVideoPath)
            progressCallback(0.0, "Installation failed")
            return
        }
        
        try? FileManager.default.removeItem(atPath: tempVideoPath)
        progressCallback(1.0, "Wallpaper replaced! Check System Settings!")
        print("Replacement completed successfully!")
    }
    
    private func executeAllCommands(tempVideoPath: String, targetPath: String, backupPath: String, progressCallback: @escaping (Double, String) -> Void) async -> Bool {
        print("Requesting admin privileges for complete cleanup operation...")
        
        await MainActor.run {
            progressCallback(0.5, "Cleaning and installing wallpaper...")
        }
        
        let batchScript = """
        do shell script "
        cp '\(targetPath)' '\(backupPath)'
        find '\(wallpaperPath)' -name '*.mov' -type f -delete
        find '\(wallpaperPath)' -name '*.backup.*' -type f -delete
        cp '\(tempVideoPath)' '\(targetPath)'
        killall WallpaperAgent 2>/dev/null || true
        " with administrator privileges
        """
        
        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let appleScript = NSAppleScript(source: batchScript)
                var error: NSDictionary?
                let result = appleScript?.executeAndReturnError(&error)
                
                if let error = error {
                    print("Batch operation failed: \(error)")
                    continuation.resume(returning: false)
                } else {
                    print("Complete cleanup successful! All old files removed.")
                    continuation.resume(returning: true)
                }
            }
        }
        
        if success {
            await MainActor.run {
                progressCallback(0.9, "Refreshing system...")
            }
        }
        
        return success
    }
}

// MARK: - Premium ContentView
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

// MARK: - Supporting Views
struct CategoryButton: View {
    let category: VideoCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : category.color)
                
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(height: 70)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? category.color : category.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(category.color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct VideoCard: View {
    let video: WallpaperVideo
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Thumbnail placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [video.category.color.opacity(0.3), video.category.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 160)
                    .overlay(
                        VStack {
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white.opacity(0.8))
                            Text(video.duration)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(video.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Text(video.resolution)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? video.category.color : Color.clear, lineWidth: 2)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .shadow(color: isSelected ? video.category.color.opacity(0.3) : .black.opacity(0.1), radius: isSelected ? 10 : 5)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomVideoCard: View {
    let videoURL: URL
    
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "video.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("Custom Video")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                )
            
            VStack(spacing: 8) {
                Text(videoURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(videoURL.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.blue.opacity(0.5), lineWidth: 2)
                )
        )
    }
}

struct EmptyCustomVideoView: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.7))
            
            Text("No Custom Video Selected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose a video file from your computer to use as wallpaper")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Choose Video File", action: action)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.blue.opacity(0.3), lineWidth: 2)
                )
        )
    }
}

struct DetectionCard: View {
    let detectedWallpaper: String
    private let wallpaperPath = "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if detectedWallpaper.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Detecting...")
                        .foregroundColor(.secondary)
                }
                .frame(height: 80)
            } else if detectedWallpaper.contains("No wallpaper") || detectedWallpaper.contains("Error") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Setup Required")
                            .fontWeight(.semibold)
                    }
                    
                    Text("Set a video wallpaper in System Settings first")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 80)
            } else {
                HStack(spacing: 12) {
                    // Wallpaper preview
                    WallpaperPreview(wallpaperName: detectedWallpaper, wallpaperPath: wallpaperPath)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ready")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        Text(detectedWallpaper)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                        
                        Text("Live wallpaper detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct WallpaperPreview: View {
    let wallpaperName: String
    let wallpaperPath: String
    @State private var hasPreview = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 60, height: 45)
            .overlay(
                Group {
                    if hasPreview {
                        // If we could load the actual video preview, show it here
                        // For now, show a nice icon
                        Image(systemName: "play.rectangle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            )
            .onAppear {
                checkForPreview()
            }
    }
    
    private func checkForPreview() {
        let filePath = "\(wallpaperPath)/\(wallpaperName).mov"
        hasPreview = FileManager.default.fileExists(atPath: filePath)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
