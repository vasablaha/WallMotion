//
//  YouTubeImportManager.swift
//  WallMotion
//
//  Clean YouTube video download and processing manager
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
        let status = dependenciesManager.checkDependencies()
        return (ytdlp: status.ytdlp, ffmpeg: status.ffmpeg)
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
        
        let deps = dependenciesManager.checkDependencies()
        guard deps.ytdlp else {
            print("❌ yt-dlp not found")
            throw YouTubeError.ytDlpNotFound
        }

        let ytdlpPaths = ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp", "/usr/bin/yt-dlp"]
        guard let ytdlpPath = ytdlpPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
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
        
        let deps = dependenciesManager.checkDependencies()
        guard deps.ytdlp else {
            throw YouTubeError.ytDlpNotFound
        }


        isDownloading = true
        downloadProgress = 0.0
        
        let uniqueID = UUID().uuidString
        let baseFilename = "youtube_video_\(uniqueID)"
        let outputTemplate = tempDirectory.appendingPathComponent("\(baseFilename).%(ext)s").path
        
        // Check if yt-dlp exists
        let ytdlpPaths = ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp", "/usr/bin/yt-dlp"]
        guard let ytdlpPath = ytdlpPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw YouTubeError.ytDlpNotFound
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ytdlpPath)
            
            // Preserve your original format string
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
            
            var allOutput = ""
            var allErrors = ""
            
            // Monitor stdout for progress
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    allOutput += output
                    
                    // Call parseDownloadProgress directly (now nonisolated)
                    self.parseDownloadProgress(output, progressCallback: progressCallback)
                }
            }
            
            // Monitor stderr
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    allErrors += output
                }
            }
            
            do {
                try task.run()
                task.waitUntilExit()
                
                // Stop monitoring pipes
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.downloadProgress = 1.0
                    progressCallback(1.0, "Download completed")
                }
                
                if task.terminationStatus == 0 {
                    let downloadedFile = self.findBestDownloadedFile(baseFilename: baseFilename, inDirectory: self.tempDirectory)
                    
                    if let fileURL = downloadedFile {
                        print("✅ Download successful: \(fileURL.path)")
                        
                        // Verify codec and re-encode if needed
                        Task {
                            do {
                                let videoInfo = try await self.getVideoProperties(at: fileURL)
                                print("🎬 Downloaded video: \(videoInfo.qualityDescription), \(videoInfo.codec)")
                                
                                if self.isCodecCompatible(videoInfo.codec) {
                                    await MainActor.run { self.downloadedVideoURL = fileURL }
                                    continuation.resume(returning: fileURL)
                                } else {
                                    print("⚠️ Re-encoding \(videoInfo.codec) to H.264...")
                                    
                                    // ✅ OKAMŽITĚ ZOBRAZ "CONVERTING" PŘED SPUŠTĚNÍM FFMPEG
                                    await MainActor.run {
                                        progressCallback(0.5, "Converting to H.264 codec...")
                                    }
                                    
                                    // ✅ MALÉ ZPOŽDĚNÍ ABY SE UI STIHLO PŘEKRESLIT
                                    try await Task.sleep(for: .milliseconds(500))
                                    
                                    // Teď spusť encoding
                                    do {
                                        let reEncodedURL = try await self.smartReEncodeToH264(
                                            fileURL,
                                            originalInfo: videoInfo,
                                            progressCallback: { _, _ in } // Prázdný callback během encoding
                                        )
                                        
                                        // ✅ Po dokončení encoding zavolej callback s "completed"
                                        await MainActor.run {
                                            self.downloadedVideoURL = reEncodedURL
                                            self.isDownloading = false
                                            // ✅ Tento callback NERESETU isProcessing - jen updatuje message
                                            progressCallback(1.0, "Video converted successfully!")
                                        }
                                        
                                        continuation.resume(returning: reEncodedURL)
                                        
                                    } catch {
                                        await MainActor.run {
                                            self.isDownloading = false
                                            progressCallback(0.0, "Conversion failed")
                                        }
                                        continuation.resume(throwing: error)
                                    }
                                }
                            } catch {
                                await MainActor.run {
                                    self.isDownloading = false
                                }
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        print("❌ Downloaded file not found")
                        continuation.resume(throwing: YouTubeError.fileNotFound)
                    }
                } else {
                    print("❌ Download failed with exit code: \(task.terminationStatus)")
                    continuation.resume(throwing: YouTubeError.downloadFailed)
                }
                
            } catch {
                print("❌ Failed to start yt-dlp process: \(error)")
                DispatchQueue.main.async { self.isDownloading = false }
                continuation.resume(throwing: error)
            }
        }
    }
    
    func trimVideo(inputURL: URL, startTime: Double, endTime: Double, outputPath: URL) async throws {
        let deps = dependenciesManager.checkDependencies()
        guard deps.ffmpeg else {
            throw YouTubeError.ffmpegNotFound
        }
        
        let duration = endTime - startTime
        
        print("✂️ Trimming video: \(startTime)s to \(endTime)s (\(duration)s)")
        
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
        videoInfo = nil
        selectedStartTime = 0.0
        selectedEndTime = 30.0
        downloadProgress = 0.0
        statusMessage = ""
    }
    
    // MARK: - Progress Parsing (nonisolated)
    
    nonisolated func parseDownloadProgress(_ output: String, progressCallback: @escaping (Double, String) -> Void) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.contains("[download]") && line.contains("%") {
                let components = line.components(separatedBy: " ").filter { !$0.isEmpty }
                for component in components {
                    if component.hasSuffix("%") {
                        if let percentString = component.dropLast().split(separator: ".").first,
                           let percent = Double(percentString) {
                            let progress = percent / 100.0
                            
                            Task { @MainActor in
                                self.downloadProgress = progress
                                progressCallback(progress, "Downloading video... \(Int(percent))%")
                            }
                            break
                        }
                    }
                }
            }
        }
    }
    
    nonisolated func parseFFmpegProgress(_ output: String, totalDuration: Double, progressCallback: @escaping (Double, String) -> Void) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.hasPrefix("out_time_ms=") {
                let timeString = String(line.dropFirst("out_time_ms=".count))
                if let microseconds = Double(timeString) {
                    let currentSeconds = microseconds / 1_000_000.0
                    let progress = min(currentSeconds / totalDuration, 1.0)
                    let percentage = Int(progress * 100)
                    
                    Task { @MainActor in
                        self.downloadProgress = progress
                        // ✅ VYLEPŠENÁ ZPRÁVA:
                        progressCallback(progress, "Converting to H.264 codec... \(percentage)%")
                    }
                }
                break
            } else if line.hasPrefix("time=") {
                // Fallback: parse time=00:00:10.50 format
                let timeString = String(line.dropFirst("time=".count)).components(separatedBy: " ").first ?? ""
                if let timeComponents = parseTimeString(timeString) {
                    let currentSeconds = timeComponents
                    let progress = min(currentSeconds / totalDuration, 1.0)
                    let percentage = Int(progress * 100)
                    
                    Task { @MainActor in
                        self.downloadProgress = progress
                        // ✅ VYLEPŠENÁ ZPRÁVA:
                        progressCallback(progress, "Converting to H.264 codec... \(percentage)%")
                    }
                }
                break
            }
        }
    }

    nonisolated func parseTimeString(_ timeString: String) -> Double? {
        // Parse format: "00:01:23.45"
        let components = timeString.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ":")
        guard components.count == 3 else { return nil }
        
        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else { return nil }
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
}

// MARK: - Private Methods

private extension YouTubeImportManager {
    
    func findBestDownloadedFile(baseFilename: String, inDirectory directory: URL) -> URL? {
        do {
            let allFiles = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            let matchingFiles = allFiles.filter { $0.hasPrefix(baseFilename) }
            
            guard !matchingFiles.isEmpty else { return nil }
            
            // Priority: merged MP4 > video MP4 > any video format
            var bestFile: String?
            var bestPriority = Int.max
            
            for filename in matchingFiles {
                let priority = getFilePriority(filename)
                if priority < bestPriority {
                    bestPriority = priority
                    bestFile = filename
                }
            }
            
            if let selectedFile = bestFile {
                let fileURL = directory.appendingPathComponent(selectedFile)
                
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attributes[.size] as? Int64, fileSize > 1000 {
                    return fileURL
                }
            }
            
            return nil
        } catch {
            print("❌ Error finding downloaded file: \(error)")
            return nil
        }
    }
    
    func getFilePriority(_ filename: String) -> Int {
        let lowercaseFilename = filename.lowercased()
        
        // Audio-only formats - avoid
        if lowercaseFilename.contains(".webm") && lowercaseFilename.contains("f251") {
            return 1000
        }
        if lowercaseFilename.hasSuffix(".m4a") || lowercaseFilename.hasSuffix(".opus") {
            return 999
        }
        
        // Merged video files - best
        if lowercaseFilename.hasSuffix(".mp4") && !lowercaseFilename.contains(".f") {
            return 1
        }
        
        // Video MP4 files with format codes
        if lowercaseFilename.hasSuffix(".mp4") {
            return 2
        }
        
        // Other video formats
        if lowercaseFilename.hasSuffix(".mov") || lowercaseFilename.hasSuffix(".mkv") {
            return 10
        }
        
        return 50
    }
    
    func getVideoProperties(at url: URL) async throws -> VideoProperties {
        let asset = AVAsset(url: url)
        
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)
        
        let videoDuration = CMTimeGetSeconds(duration)
        let videoTracks = tracks.filter { $0.mediaType == .video }
        let audioTracks = tracks.filter { $0.mediaType == .audio }
        
        var resolution = CGSize.zero
        var codec = "Unknown"
        
        if let videoTrack = videoTracks.first {
            let naturalSize = try await videoTrack.load(.naturalSize)
            resolution = naturalSize
            
            let formatDescriptions = videoTrack.formatDescriptions
            for description in formatDescriptions {
                let formatDescription = description as! CMVideoFormatDescription
                let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                codec = fourCharCodeToString(codecType)
                break
            }
        }
        
        return VideoProperties(
            duration: videoDuration,
            resolution: resolution,
            videoTracks: videoTracks.count,
            audioTracks: audioTracks.count,
            codec: codec,
            isPlayable: videoDuration > 0 && !videoTracks.isEmpty
        )
    }
    
    func isCodecCompatible(_ codec: String) -> Bool {
        let compatibleCodecs = ["avc1", "h264", "mp4v", "hvc1", "hev1"]
        return compatibleCodecs.contains { compatibleCodec in
            codec.lowercased().contains(compatibleCodec.lowercased())
        }
    }
    
    // V YouTubeImportManager.swift - aktualizujte začátek smartReEncodeToH264:

    func smartReEncodeToH264(_ inputURL: URL, originalInfo: VideoProperties, progressCallback: @escaping (Double, String) -> Void) async throws -> URL {
        let outputURL = tempDirectory.appendingPathComponent("h264_\(UUID().uuidString).mp4")
        
        print("🔄 Re-encoding started: \(Int(originalInfo.resolution.width))x\(Int(originalInfo.resolution.height))")
        
        let deps = dependenciesManager.checkDependencies()
        guard deps.ffmpeg else {
            throw YouTubeError.ffmpegNotFound
        }
        
        let ffmpegPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        guard let ffmpegPath = ffmpegPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw YouTubeError.ffmpegNotFound
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            // ✅ SPUSŤ FFMPEG NA BACKGROUND QUEUE
            Task.detached {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: ffmpegPath)
                
                task.arguments = [
                    "-i", inputURL.path,
                    "-t", String(originalInfo.duration),
                    "-c:v", "libx264",
                    "-preset", "medium",
                    "-crf", "18",
                    "-profile:v", "high",
                    "-level:v", "5.1",
                    "-pix_fmt", "yuv420p",
                    "-vf", "scale=\(Int(originalInfo.resolution.width)):\(Int(originalInfo.resolution.height))",
                    "-c:a", "aac",
                    "-b:a", "128k",
                    "-movflags", "+faststart",
                    "-avoid_negative_ts", "make_zero",
                    "-y",
                    outputURL.path
                ]
                
                // ✅ ŽÁDNÉ PIPES - jen jednoduché spuštění
                do {
                    try task.run()
                    task.waitUntilExit() // Toto běží na background thread, takže neblokuje UI
                    
                    if task.terminationStatus == 0 {
                        if FileManager.default.fileExists(atPath: outputURL.path) {
                            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
                            if let fileSize = attributes[.size] as? Int64, fileSize > 1000 {
                                print("✅ Re-encoding completed successfully")
                                
                                // Clean up original file
                                try? FileManager.default.removeItem(at: inputURL)
                                
                                continuation.resume(returning: outputURL)
                                return
                            }
                        }
                    }
                    
                    print("❌ Re-encoding failed with exit code: \(task.terminationStatus)")
                    continuation.resume(throwing: YouTubeError.processingFailed)
                    
                } catch {
                    print("❌ Failed to start re-encoding: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fourCharCodeToString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "Unknown"
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
            return "yt-dlp not installed. Please install via: brew install yt-dlp"
        case .ffmpegNotFound:
            return "FFmpeg not installed. Please install via: brew install ffmpeg"
        }
    }
}
