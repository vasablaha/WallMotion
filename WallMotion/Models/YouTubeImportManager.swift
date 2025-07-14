//
//  YouTubeImportManager.swift
//  WallMotion
//
//  YouTube video import and processing manager - Updated
//

import Foundation
import AVKit
import Combine

class YouTubeImportManager: ObservableObject {
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var statusMessage = ""
    @Published var downloadedVideoURL: URL?
    @Published var videoInfo: YouTubeVideoInfo?
    @Published var selectedStartTime: Double = 0.0
    @Published var selectedEndTime: Double = 30.0
    @Published var maxDuration: Double = 300.0 // 5 minut max pro wallpaper
    
    let tempDirectory = FileManager.default.temporaryDirectory
    private var downloadTask: Process?
    
    struct YouTubeVideoInfo {
        let title: String
        let duration: Double
        let thumbnail: String
        let quality: String
        let url: String
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
        let ytdlpPaths = ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp", "/usr/bin/yt-dlp"]
        guard let ytdlpPath = ytdlpPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("❌ yt-dlp not found in any of these paths: \(ytdlpPaths)")
            throw YouTubeError.ytDlpNotFound
        }
        
        print("✅ Using yt-dlp at: \(ytdlpPath)")
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ytdlpPath)
            task.arguments = [
                "--print", "title,duration,thumbnail,height",
                "--no-download",
                urlString
            ]
            
            print("🚀 Executing: \(ytdlpPath) \(task.arguments!.joined(separator: " "))")
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                print("🏁 Info task finished with status: \(task.terminationStatus)")
                
                if task.terminationStatus == 0 {
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    print("📄 Raw output: '\(output)'")
                    
                    let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    print("📝 Parsed lines: \(lines)")
                    
                    if lines.count >= 4 {
                        let duration = Double(lines[1]) ?? 0
                        let info = YouTubeVideoInfo(
                            title: lines[0],
                            duration: duration,
                            thumbnail: lines[2],
                            quality: "\(lines[3])p",
                            url: urlString
                        )
                        
                        // Update maxDuration based on actual video duration
                        DispatchQueue.main.async {
                            self.maxDuration = min(duration, 300.0) // Max 5 minutes for wallpaper
                            self.selectedEndTime = min(30.0, self.maxDuration)
                        }
                        
                        print("✅ Video info parsed successfully: \(info.title), duration: \(duration)s")
                        continuation.resume(returning: info)
                    } else {
                        print("❌ Invalid video info - expected 4 lines, got \(lines.count)")
                        continuation.resume(throwing: YouTubeError.invalidVideoInfo)
                    }
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    print("❌ Info retrieval failed: \(errorString)")
                    continuation.resume(throwing: YouTubeError.downloadFailed)
                }
            } catch {
                print("❌ Failed to start info process: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    func downloadVideo(from urlString: String, progressCallback: @escaping (Double, String) -> Void) async throws -> URL {
        print("🎥 Starting YouTube download process...")
        print("📍 Temp directory: \(tempDirectory.path)")
        
        isDownloading = true
        downloadProgress = 0.0
        
        // Create unique filename
        let uniqueID = UUID().uuidString
        let baseFilename = "youtube_video_\(uniqueID)"
        let outputTemplate = tempDirectory.appendingPathComponent("\(baseFilename).%(ext)s").path
        
        print("📝 Output template: \(outputTemplate)")
        
        // Check if yt-dlp exists
        let ytdlpPaths = ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp", "/usr/bin/yt-dlp"]
        guard let ytdlpPath = ytdlpPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("❌ yt-dlp not found in any of these paths: \(ytdlpPaths)")
            throw YouTubeError.ytDlpNotFound
        }
        
        print("✅ Found yt-dlp at: \(ytdlpPath)")
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ytdlpPath)
            task.arguments = [
                "-f", "bestvideo[height<=1080]+bestaudio/best[height<=1080]", // Limit to 1080p for performance
                "--merge-output-format", "mp4",
                "-o", outputTemplate,
                "--newline",
                urlString
            ]
            
            print("🚀 Executing command: \(ytdlpPath) \(task.arguments!.joined(separator: " "))")
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            var allOutput = ""
            var allErrors = ""
            
            // Monitor stdout
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    allOutput += output
                    self.parseDownloadProgress(output, progressCallback: progressCallback)
                }
            }
            
            // Monitor stderr
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    allErrors += output
                    self.parseDownloadProgress(output, progressCallback: progressCallback)
                }
            }
            
            do {
                try task.run()
                downloadTask = task
                
                task.terminationHandler = { _ in
                    // Close pipes
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    DispatchQueue.main.async {
                        self.isDownloading = false
                        
                        print("🏁 Task finished with status: \(task.terminationStatus)")
                        
                        if task.terminationStatus == 0 {
                            // Find downloaded file
                            let downloadedFile = self.findDownloadedFile(baseFilename: baseFilename, inDirectory: self.tempDirectory)
                            
                            if let fileURL = downloadedFile {
                                print("✅ Found downloaded file: \(fileURL.path)")
                                self.downloadedVideoURL = fileURL
                                
                                // Initialize time selector with video duration - FIXED bounds
                                if let videoInfo = self.videoInfo {
                                    let videoDuration = max(30, videoInfo.duration) // Minimum 30 seconds
                                    self.maxDuration = min(videoDuration, 300.0)
                                    self.selectedStartTime = 0.0
                                    self.selectedEndTime = min(30.0, self.maxDuration - 5)
                                }
                                
                                continuation.resume(returning: fileURL)
                            } else {
                                print("❌ Downloaded file not found!")
                                self.listDirectoryContents(self.tempDirectory)
                                continuation.resume(throwing: YouTubeError.fileNotFound)
                            }
                        } else {
                            print("❌ Download failed with exit code: \(task.terminationStatus)")
                            print("❗ Error output: \(allErrors)")
                            continuation.resume(throwing: YouTubeError.downloadFailed)
                        }
                    }
                }
                
            } catch {
                print("❌ Failed to start yt-dlp process: \(error)")
                isDownloading = false
                continuation.resume(throwing: error)
            }
        }
    }
    
    func trimVideo(inputURL: URL, startTime: Double, endTime: Double, outputPath: URL) async throws {
        let duration = endTime - startTime
        
        print("✂️ Trimming video:")
        print("   📁 Input: \(inputURL.path)")
        print("   📁 Output: \(outputPath.path)")
        print("   ⏰ Start: \(startTime)s, Duration: \(duration)s")
        
        // Check if ffmpeg exists
        let ffmpegPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        guard let ffmpegPath = ffmpegPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("❌ FFmpeg not found in any of these paths: \(ffmpegPaths)")
            throw YouTubeError.ffmpegNotFound
        }
        
        print("✅ Using FFmpeg at: \(ffmpegPath)")
        
        // Verify input file exists
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            print("❌ Input file does not exist: \(inputURL.path)")
            throw YouTubeError.fileNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ffmpegPath)
            task.arguments = [
                "-i", inputURL.path,
                "-ss", String(format: "%.2f", startTime),
                "-t", String(format: "%.2f", duration),
                "-c:v", "libx264",
                "-c:a", "aac",
                "-preset", "medium", // Better quality than "fast"
                "-crf", "18", // Better quality than "20"
                "-vf", "scale=-2:1080", // Ensure proper scaling
                "-movflags", "+faststart",
                "-y", // Overwrite output file
                outputPath.path
            ]
            
            print("🚀 Executing: \(ffmpegPath) \(task.arguments!.joined(separator: " "))")
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            var allErrors = ""
            
            // Monitor error output for progress
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    allErrors += output
                }
            }
            
            do {
                try task.run()
                
                task.terminationHandler = { _ in
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    print("🏁 FFmpeg finished with status: \(task.terminationStatus)")
                    
                    if task.terminationStatus == 0 {
                        // Verify output file was created
                        if FileManager.default.fileExists(atPath: outputPath.path) {
                            do {
                                let attributes = try FileManager.default.attributesOfItem(atPath: outputPath.path)
                                if let fileSize = attributes[.size] as? Int64, fileSize > 0 {
                                    print("✅ Trimmed video created: \(outputPath.path) (\(fileSize) bytes)")
                                    continuation.resume()
                                } else {
                                    print("❌ Output file is empty")
                                    continuation.resume(throwing: YouTubeError.processingFailed)
                                }
                            } catch {
                                print("❌ Error checking output file: \(error)")
                                continuation.resume(throwing: YouTubeError.processingFailed)
                            }
                        } else {
                            print("❌ Output file was not created")
                            continuation.resume(throwing: YouTubeError.processingFailed)
                        }
                    } else {
                        print("❌ FFmpeg failed with exit code: \(task.terminationStatus)")
                        print("❗ FFmpeg errors: \(allErrors)")
                        continuation.resume(throwing: YouTubeError.processingFailed)
                    }
                }
            } catch {
                print("❌ Failed to start FFmpeg process: \(error)")
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
    
    // MARK: - Private Methods
    
    private func parseDownloadProgress(_ output: String, progressCallback: @escaping (Double, String) -> Void) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // Parse yt-dlp progress: [download]  45.2% of 123.45MiB at 1.23MiB/s ETA 00:42
            if line.contains("[download]") && line.contains("%") {
                let components = line.components(separatedBy: " ").filter { !$0.isEmpty }
                for component in components {
                    if component.hasSuffix("%") {
                        if let percentString = component.dropLast().split(separator: ".").first,
                           let percent = Double(percentString) {
                            let progress = percent / 100.0
                            
                            DispatchQueue.main.async {
                                self.downloadProgress = progress
                                progressCallback(progress, "Downloading... \(Int(percent))%")
                            }
                            break
                        }
                    }
                }
            }
        }
    }
    
    private func findDownloadedFile(baseFilename: String, inDirectory directory: URL) -> URL? {
        print("🔍 Searching for files with base: \(baseFilename)")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            let matchingFiles = files.filter { $0.hasPrefix(baseFilename) }
            print("🎯 Matching files: \(matchingFiles)")
            
            if let firstMatch = matchingFiles.first {
                let fullPath = directory.appendingPathComponent(firstMatch)
                
                // Verify file exists and has content
                let attributes = try FileManager.default.attributesOfItem(atPath: fullPath.path)
                if let fileSize = attributes[.size] as? Int64, fileSize > 0 {
                    print("✅ Selected file: \(fullPath.path) (\(fileSize) bytes)")
                    return fullPath
                } else {
                    print("❌ File is empty!")
                }
            }
        } catch {
            print("❌ Error reading directory: \(error)")
        }
        
        return nil
    }
    
    private func listDirectoryContents(_ directory: URL) {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            print("📁 Directory contents (\(files.count) files):")
            for file in files {
                let fullPath = directory.appendingPathComponent(file).path
                if let attributes = try? FileManager.default.attributesOfItem(atPath: fullPath),
                   let size = attributes[.size] as? Int64 {
                    print("  📄 \(file) (\(size) bytes)")
                } else {
                    print("  📄 \(file)")
                }
            }
        } catch {
            print("❌ Error listing directory: \(error)")
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        if let videoURL = downloadedVideoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }
        downloadedVideoURL = nil
        videoInfo = nil
        selectedStartTime = 0.0
        selectedEndTime = 30.0
        maxDuration = 300.0
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
            return "yt-dlp not installed. Please install via: brew install yt-dlp"
        case .ffmpegNotFound:
            return "FFmpeg not installed. Please install via: brew install ffmpeg"
        }
    }
}

// MARK: - Installation Helper

extension YouTubeImportManager {
    func checkDependencies() -> (ytdlp: Bool, ffmpeg: Bool) {
        let ytdlpExists = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/yt-dlp") ||
                         FileManager.default.fileExists(atPath: "/usr/local/bin/yt-dlp") ||
                         FileManager.default.fileExists(atPath: "/usr/bin/yt-dlp")
        
        let ffmpegExists = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/ffmpeg") ||
                          FileManager.default.fileExists(atPath: "/usr/local/bin/ffmpeg") ||
                          FileManager.default.fileExists(atPath: "/usr/bin/ffmpeg")
        
        return (ytdlp: ytdlpExists, ffmpeg: ffmpegExists)
    }
    
    func installationInstructions() -> String {
        let deps = checkDependencies()
        var instructions: [String] = []
        
        if !deps.ytdlp {
            instructions.append("• Install yt-dlp: brew install yt-dlp")
        }
        
        if !deps.ffmpeg {
            instructions.append("• Install ffmpeg: brew install ffmpeg")
        }
        
        if instructions.isEmpty {
            return "All dependencies are installed! ✅"
        } else {
            return "Missing dependencies:\n\n" + instructions.joined(separator: "\n") +
                   "\n\nRun these commands in Terminal, then restart WallMotion."
        }
    }
}
