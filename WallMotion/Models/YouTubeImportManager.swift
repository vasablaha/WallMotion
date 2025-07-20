//
//  YouTubeImportManager.swift
//  WallMotion
//
//  Simplified YouTube video download manager using DependenciesManager
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
class YouTubeImportManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var statusMessage = ""
    @Published var downloadedVideoURL: URL?
    @Published var videoInfo: YouTubeVideoInfo?
    @Published var selectedStartTime: Double = 0.0
    @Published var selectedEndTime: Double = 30.0
    @Published var maxDuration: Double = 300.0 // 5 minutes max for wallpaper
    
    // MARK: - Dependencies
    @Published var dependenciesManager = DependenciesManager()
    
    // MARK: - Properties
    let tempDirectory = FileManager.default.temporaryDirectory
    private var downloadTask: Process?
    
    // MARK: - Data Structures
    
    struct YouTubeVideoInfo {
        let title: String
        let duration: Double
        let thumbnail: String
        let quality: String
        let url: String
    }
    
    struct VideoProperties {
        let duration: Double
        let resolution: CGSize
        let videoTracks: Int
        let audioTracks: Int
        let codec: String
        let isPlayable: Bool
        
        var qualityDescription: String {
            let width = Int(resolution.width)
            let height = Int(resolution.height)
            
            if height >= 2160 {
                return "4K (\(width)x\(height))"
            } else if height >= 1440 {
                return "2K (\(width)x\(height))"
            } else if height >= 1080 {
                return "HD (\(width)x\(height))"
            } else if height >= 720 {
                return "HD Ready (\(width)x\(height))"
            } else {
                return "SD (\(width)x\(height))"
            }
        }
    }
    
    // MARK: - Convenience Methods for Dependencies
    
    func checkDependencies() -> (ytdlp: Bool, ffmpeg: Bool) {
        let deps = ExecutableManager.shared.checkAllDependencies()
        return (ytdlp: deps.ytdlp, ffmpeg: deps.ffmpeg)
    }
    
    func installationInstructions() -> String {
        return dependenciesManager.getInstallationInstructions()
    }
    
    // MARK: - Public Methods
    
    func validateYouTubeURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        let youtubePatterns = [
            "youtube.com/watch",
            "youtu.be/",
            "youtube.com/embed/",
            "youtube.com/v/"
        ]
        
        return youtubePatterns.contains { url.absoluteString.contains($0) }
    }
    
    func getVideoInfo(from urlString: String) async throws -> YouTubeVideoInfo {
        print("📋 Getting video info for: \(urlString)")
        
        guard validateYouTubeURL(urlString) else {
            print("❌ Invalid YouTube URL")
            throw YouTubeError.invalidURL
        }
        
        // Check if yt-dlp exists
        let deps = dependenciesManager.checkDependencies()
        guard deps.ytdlp else {
            print("❌ yt-dlp not found")
            throw YouTubeError.ytDlpNotFound
        }
        
        guard let ytdlpPath = ExecutableManager.shared.ytdlpPath?.path else {
            throw YouTubeError.ytDlpNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ytdlpPath)
            
            task.arguments = [
                "--print", "%(title)s",
                "--print", "%(duration)s",
                "--print", "%(thumbnail)s",
                "--no-download",
                "--no-warnings",
                urlString
            ]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus == 0 {
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    let lines = output.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    
                    var title = "Unknown Title"
                    var duration: Double = 0.0
                    var thumbnail = ""
                    
                    if lines.count >= 1 { title = lines[0] }
                    if lines.count >= 2, let durationValue = Double(lines[1]) { duration = durationValue }
                    if lines.count >= 3 { thumbnail = lines[2] }
                    
                    let quality = "Video available"
                    
                    let videoInfo = YouTubeVideoInfo(
                        title: title,
                        duration: duration,
                        thumbnail: thumbnail,
                        quality: quality,
                        url: urlString
                    )
                    
                    print("✅ Video info: \(title) (\(duration)s)")
                    continuation.resume(returning: videoInfo)
                    
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    print("❌ Info retrieval failed: \(errorString)")
                    continuation.resume(throwing: YouTubeError.invalidVideoInfo)
                }
            } catch {
                print("❌ Failed to start info process: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    func downloadVideo(from urlString: String, progressCallback: @escaping (Double, String) -> Void) async throws -> URL {
        print("🎥 Starting YouTube download process...")

        guard let ytdlpPath = ExecutableManager.shared.ytdlpPath?.path else {
            throw YouTubeError.ytDlpNotFound
        }

        isDownloading = true
        downloadProgress = 0.0
        
        let uniqueID = UUID().uuidString
        let baseFilename = "youtube_video_\(uniqueID)"
        let outputTemplate = tempDirectory.appendingPathComponent("\(baseFilename).%(ext)s").path
        
        guard let ytdlpPath = dependenciesManager.findExecutablePath(for: "yt-dlp") else {
            throw YouTubeError.ytDlpNotFound
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ytdlpPath)
            
            task.arguments = [
                "-f", "bestvideo[ext=mp4][height<=2160]/bestvideo[height<=2160]/bestvideo[ext=mp4]/bestvideo",
                "--merge-output-format", "mp4",
                "-o", outputTemplate,
                "--no-playlist",
                "--newline",
                "--no-warnings",
                "--retries", "3",
                "--socket-timeout", "30",
                "--force-ipv4",
                urlString
            ]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            // Use actor-isolated data storage
            let outputCollector = OutputCollector()
            let errorCollector = OutputCollector()
            
            // Monitor stdout for progress
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    Task {
                        await outputCollector.append(data)
                    }
                    
                    // Only log progress lines and errors, not all output
                    if output.contains("[download]") && output.contains("%") {
                        let lines = output.components(separatedBy: .newlines)
                        for line in lines {
                            if line.contains("[download]") && line.contains("%") {
                                print("📥 \(line.trimmingCharacters(in: .whitespacesAndNewlines))")
                                break
                            }
                        }
                    }
                    
                    // Parse download progress on main thread
                    DispatchQueue.main.async {
                        self.parseDownloadProgress(output, progressCallback: progressCallback)
                    }
                }
            }
            
            // Monitor stderr
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    Task {
                        await errorCollector.append(data)
                    }
                }
            }
            
            task.terminationHandler = { task in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                if task.terminationStatus == 0 {
                    Task { @MainActor in
                        let mp4Files = self.findDownloadedFiles(in: self.tempDirectory, matching: baseFilename)
                        
                        if let videoFile = mp4Files.first {
                            print("✅ Video downloaded: \(videoFile.lastPathComponent)")
                            
                            // Check if we need to re-encode
                            let videoProperties = await self.analyzeVideoProperties(videoFile)
                            print("📊 Video info: \(videoProperties.qualityDescription), \(videoProperties.codec)")
                            
                            if self.isCodecCompatible(videoProperties.codec) {
                                print("✅ Codec is compatible, no re-encoding needed")
                                self.isDownloading = false
                                self.downloadedVideoURL = videoFile
                                continuation.resume(returning: videoFile)
                            } else {
                                print("🔄 Codec \(videoProperties.codec) is not compatible, re-encoding to H.264...")
                                
                                // Update UI to show re-encoding status
                                progressCallback(0.0, "Converting to H.264 codec...")
                                
                                do {
                                    let reEncodedURL = try await self.smartReEncodeToH264(
                                        videoFile,
                                        originalInfo: videoProperties,
                                        progressCallback: progressCallback
                                    )
                                    
                                    print("✅ Re-encoding completed successfully")
                                    self.isDownloading = false
                                    self.downloadedVideoURL = reEncodedURL
                                    continuation.resume(returning: reEncodedURL)
                                    
                                } catch {
                                    print("❌ Re-encoding failed: \(error)")
                                    self.isDownloading = false
                                    continuation.resume(throwing: error)
                                }
                            }
                        } else {
                            print("❌ Downloaded file not found")
                            self.isDownloading = false
                            continuation.resume(throwing: YouTubeError.fileNotFound)
                        }
                    }
                } else {
                    print("❌ Download failed with exit code: \(task.terminationStatus)")
                    
                    Task {
                        let errorString = await errorCollector.getString()
                        print("Error output: \(errorString)")
                        
                        Task { @MainActor in
                            self.isDownloading = false
                        }
                        continuation.resume(throwing: YouTubeError.downloadFailed)
                    }
                }
            }
            
            do {
                try task.run()
                self.downloadTask = task
            } catch {
                print("❌ Failed to start download: \(error)")
                Task { @MainActor in
                    self.isDownloading = false
                }
                continuation.resume(throwing: error)
            }
        }
    }
    
    func trimVideo(_ inputURL: URL, startTime: Double, endTime: Double, outputPath: URL) async throws {
        print("✂️ Trimming video: \(startTime)s to \(endTime)s")
        
        // Check FFmpeg dependency
        let deps = dependenciesManager.checkDependencies()
        guard deps.ffmpeg else {
            throw YouTubeError.ffmpegNotFound
        }
        
        let duration = endTime - startTime
        
        let ffmpegPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        guard let ffmpegPath = ffmpegPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw YouTubeError.ffmpegNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ffmpegPath)
            
            task.arguments = [
                "-i", inputURL.path,
                "-ss", String(startTime),
                "-t", String(duration),
                "-c:v", "libx264",
                "-preset", "medium",
                "-crf", "23",
                "-pix_fmt", "yuv420p",
                "-movflags", "+faststart",
                "-an", // No audio for wallpapers
                "-avoid_negative_ts", "make_zero",
                "-y",
                outputPath.path
            ]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus == 0 {
                    if FileManager.default.fileExists(atPath: outputPath.path) {
                        print("✅ Video trimmed successfully")
                        continuation.resume()
                    } else {
                        print("❌ Trimmed file was not created")
                        continuation.resume(throwing: YouTubeError.processingFailed)
                    }
                } else {
                    print("❌ Trimming failed with exit code: \(task.terminationStatus)")
                    continuation.resume(throwing: YouTubeError.processingFailed)
                }
            } catch {
                print("❌ Failed to start trimming: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    func analyzeVideoProperties(_ videoURL: URL) async -> VideoProperties {
        let asset = AVURLAsset(url: videoURL)
        
        do {
            let duration = try await asset.load(.duration).seconds
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            
            var resolution = CGSize.zero
            var codec = "Unknown"
            
            if let videoTrack = videoTracks.first {
                resolution = try await videoTrack.load(.naturalSize)
                
                // Get codec information
                let formatDescriptions = try await videoTrack.load(.formatDescriptions)
                if let formatDescription = formatDescriptions.first {
                    let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                    codec = fourCharCodeToString(codecType)
                }
            }
            
            return VideoProperties(
                duration: duration,
                resolution: resolution,
                videoTracks: videoTracks.count,
                audioTracks: audioTracks.count,
                codec: codec,
                isPlayable: duration > 0 && !videoTracks.isEmpty
            )
        } catch {
            print("❌ Error analyzing video properties: \(error)")
            return VideoProperties(
                duration: 0,
                resolution: CGSize.zero,
                videoTracks: 0,
                audioTracks: 0,
                codec: "Unknown",
                isPlayable: false
            )
        }
    }
    
    func isCodecCompatible(_ codec: String) -> Bool {
        let compatibleCodecs = ["avc1", "h264", "mp4v"]
        return compatibleCodecs.contains { compatibleCodec in
            codec.lowercased().contains(compatibleCodec.lowercased())
        }
    }
    
    func smartReEncodeToH264(_ inputURL: URL, originalInfo: VideoProperties, progressCallback: @escaping (Double, String) -> Void) async throws -> URL {
        let outputURL = tempDirectory.appendingPathComponent("h264_\(UUID().uuidString).mp4")
        
        print("🔄 Re-encoding started: \(Int(originalInfo.resolution.width))x\(Int(originalInfo.resolution.height))")
        
        // Check FFmpeg dependency
        let deps = dependenciesManager.checkDependencies()
        guard deps.ffmpeg else {
            throw YouTubeError.ffmpegNotFound
        }
        
        guard let ffmpegPath = ExecutableManager.shared.ffmpegPath?.path else {
            throw YouTubeError.ffmpegNotFound
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            Task.detached {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: ffmpegPath)
                
                task.arguments = [
                    "-i", inputURL.path,
                    "-t", String(originalInfo.duration),
                    "-c:v", "libx264",
                    "-preset", "medium",
                    "-crf", "18",
                    "-pix_fmt", "yuv420p",
                    "-movflags", "+faststart",
                    "-an",
                    "-avoid_negative_ts", "make_zero",
                    "-y",
                    outputURL.path
                ]
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = errorPipe
                
                // Use actor-isolated data storage
                let outputCollector = OutputCollector()
                let errorCollector = OutputCollector()
                
                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        let output = String(data: data, encoding: .utf8) ?? ""
                        
                        Task {
                            await outputCollector.append(data)
                        }
                        
                        // Only log progress lines for FFmpeg
                        if output.contains("time=") || output.contains("frame=") {
                            let lines = output.components(separatedBy: .newlines)
                            for line in lines {
                                if line.contains("time=") || line.contains("frame=") {
                                    print("🔄 FFmpeg: \(line.trimmingCharacters(in: .whitespacesAndNewlines))")
                                    break
                                }
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.parseFFmpegProgress(output, totalDuration: originalInfo.duration, progressCallback: progressCallback)
                        }
                    }
                }
                
                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        Task {
                            await errorCollector.append(data)
                        }
                    }
                }
                
                task.terminationHandler = { task in
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    if task.terminationStatus == 0 {
                        if FileManager.default.fileExists(atPath: outputURL.path) {
                            print("✅ Re-encoding completed successfully")
                            continuation.resume(returning: outputURL)
                        } else {
                            print("❌ Re-encoded file was not created")
                            continuation.resume(throwing: YouTubeError.processingFailed)
                        }
                    } else {
                        print("❌ Re-encoding failed with exit code: \(task.terminationStatus)")
                        
                        Task {
                            let errorString = await errorCollector.getString()
                            print("Error output: \(errorString)")
                            continuation.resume(throwing: YouTubeError.processingFailed)
                        }
                    }
                }
                
                do {
                    try task.run()
                    task.waitUntilExit()
                } catch {
                    print("❌ Failed to start re-encoding: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func findDownloadedFiles(in directory: URL, matching pattern: String) -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            return files.filter { $0.lastPathComponent.contains(pattern) && $0.pathExtension == "mp4" }
        } catch {
            print("❌ Error reading directory: \(error)")
            return []
        }
    }
    
    private func parseDownloadProgress(_ output: String, progressCallback: @escaping (Double, String) -> Void) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.contains("[download]") && line.contains("%") {
                let components = line.components(separatedBy: " ")
                for component in components {
                    if component.contains("%") {
                        let percentString = component.replacingOccurrences(of: "%", with: "")
                        if let percent = Double(percentString) {
                            let progress = percent / 100.0
                            
                            // Only update if progress changed significantly or reached 100%
                            if abs(progress - downloadProgress) > 0.01 || progress >= 1.0 {
                                print("📊 Download progress: \(percent)%")
                                
                                DispatchQueue.main.async {
                                    self.downloadProgress = progress
                                    progressCallback(progress, "Downloading: \(Int(percent))%")
                                }
                            }
                            break
                        }
                    }
                }
            }
        }
    }
    
    private func parseFFmpegProgress(_ output: String, totalDuration: Double, progressCallback: @escaping (Double, String) -> Void) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // Try to parse time= format first
            if line.contains("time=") {
                let timePattern = "time=([0-9:]+\\.[0-9]+)"
                if let regex = try? NSRegularExpression(pattern: timePattern, options: []) {
                    let nsString = line as NSString
                    let results = regex.matches(in: line, options: [], range: NSMakeRange(0, nsString.length))
                    
                    for match in results {
                        let timeString = nsString.substring(with: match.range(at: 1))
                        if let timeSeconds = parseTimeToSeconds(timeString) {
                            let progress = min(timeSeconds / totalDuration, 1.0)
                            
                            // Always update progress for FFmpeg (it's slower than download)
                            print("🔄 FFmpeg progress: \(Int(progress * 100))% (\(timeString) of \(Int(totalDuration))s)")
                            
                            DispatchQueue.main.async {
                                progressCallback(progress, "Converting to H.264: \(Int(progress * 100))%")
                            }
                        }
                    }
                }
            }
            // Also try frame= format as fallback
            else if line.contains("frame=") && line.contains("time=") {
                // This is a more detailed FFmpeg output line
                let components = line.components(separatedBy: " ").filter { !$0.isEmpty }
                for component in components {
                    if component.hasPrefix("time=") {
                        let timeString = String(component.dropFirst(5)) // Remove "time="
                        if let timeSeconds = parseTimeToSeconds(timeString) {
                            let progress = min(timeSeconds / totalDuration, 1.0)
                            
                            print("🔄 FFmpeg progress: \(Int(progress * 100))% (\(timeString) of \(Int(totalDuration))s)")
                            
                            DispatchQueue.main.async {
                                progressCallback(progress, "Converting to H.264: \(Int(progress * 100))%")
                            }
                        }
                        break
                    }
                }
            }
        }
    }
    
    private func parseTimeToSeconds(_ timeString: String) -> Double? {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 3 else { return nil }
        
        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else { return nil }
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    private func fourCharCodeToString(_ fourCharCode: FourCharCode) -> String {
        let bytes = [
            UInt8((fourCharCode >> 24) & 0xFF),
            UInt8((fourCharCode >> 16) & 0xFF),
            UInt8((fourCharCode >> 8) & 0xFF),
            UInt8(fourCharCode & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "Unknown"
    }
    
    // MARK: - Control Methods
    
    func cancelDownload() {
        downloadTask?.terminate()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0.0
        statusMessage = "Download cancelled"
    }
    
    func reset() {
        cleanup()
    }
    
    func cleanup() {
        if let videoURL = downloadedVideoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }
        downloadedVideoURL = nil
        downloadProgress = 0.0
        statusMessage = ""
    }
}

// MARK: - Error Types

enum YouTubeError: LocalizedError {
    case invalidURL
    case invalidVideoInfo
    case downloadFailed
    case fileNotFound
    case processingFailed
    case ytDlpNotFound
    case ffmpegNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid YouTube URL"
        case .invalidVideoInfo:
            return "Could not retrieve video information"
        case .downloadFailed:
            return "Video download failed"
        case .fileNotFound:
            return "Downloaded file not found"
        case .processingFailed:
            return "Video processing failed"
        case .ytDlpNotFound:
            return "yt-dlp not installed. Please install dependencies first."
        case .ffmpegNotFound:
            return "FFmpeg not installed. Please install dependencies first."
        }
    }
}

// MARK: - Swift 6 Sendable Actor for Thread-Safe Data Collection

actor OutputCollector {
    private var data = Data()
    
    func append(_ newData: Data) {
        data.append(newData)
    }
    
    func getString() -> String {
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
    
    func clear() {
        data.removeAll()
    }
}
