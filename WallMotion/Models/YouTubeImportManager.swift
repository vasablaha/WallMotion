//
//  YouTubeImportManager.swift
//  WallMotion
//
//  Simplified YouTube video download manager using DependenciesManager
//

import Foundation
import AVFoundation
import SwiftUI


enum DownloadState {
    case preparing
    case downloading
    case converting
    case finalizing
    case completed
}


struct ProgressInfo {
    let state: DownloadState
    let progress: Double
    let message: String
    
    static let initial = ProgressInfo(state: .preparing, progress: 0.0, message: "Preparing download...")
}


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
    private let dependenciesManager = DependenciesManager.shared

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
    
    // ✅ OPRAVENÁ FUNKCE: Používá DependenciesManager
    func checkDependencies() -> (ytdlp: Bool, ffmpeg: Bool) {
        print("🔍 YouTube Import: Checking dependencies using DependenciesManager...")
        
        // ✅ OPRAVA: Použít DependenciesManager místo ExecutableManager
        let deps = dependenciesManager.checkDependencies()
        
        print("🔍 YouTube Import Results:")
        print("   yt-dlp: \(deps.ytdlp)")
        print("   ffmpeg: \(deps.ffmpeg)")
        
        return (ytdlp: deps.ytdlp, ffmpeg: deps.ffmpeg)
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
    
    // ✅ OPRAVENÁ: getVideoInfo s proper thread management
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
            
            guard let ytdlpPath = dependenciesManager.findExecutablePath(for: "yt-dlp") else {
                throw YouTubeError.ytDlpNotFound
            }
            
            // 🔧 FIX: Run Process on background thread, return to main thread for UI
            return try await withCheckedThrowingContinuation { continuation in
                // ✅ Process musí běžet na background thread
                Task.detached {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: ytdlpPath)
                    
                    task.arguments = [
                        "--print", "%(title)s",
                        "--print", "%(duration)s",
                        "--print", "%(thumbnail)s",
                        "--no-download",
                        "--no-warnings",
                        "--no-check-certificate",
                        urlString
                    ]
                    
                    // PyInstaller environment fix
                    var environment = ProcessInfo.processInfo.environment
                    environment["TMPDIR"] = NSTemporaryDirectory()
                    environment["TEMP"] = NSTemporaryDirectory()
                    environment["TMP"] = NSTemporaryDirectory()
                    environment["PYINSTALLER_SEMAPHORE"] = "0"
                    environment["PYI_DISABLE_SEMAPHORE"] = "1"
                    environment["_PYI_SPLASH_IPC"] = "0"
                    environment["OBJC_DISABLE_INITIALIZE_FORK_SAFETY"] = "YES"
                    
                    if let resourcePath = Bundle.main.resourcePath {
                        let currentPath = environment["PATH"] ?? ""
                        environment["PATH"] = "\(resourcePath):\(currentPath)"
                    }
                    
                    task.environment = environment
                    
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    task.standardOutput = outputPipe
                    task.standardError = errorPipe
                    
                    print("🚀 Starting yt-dlp on background thread...")
                    
                    do {
                        try task.run()
                        task.waitUntilExit()
                        
                        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        
                        let output = String(data: outputData, encoding: .utf8) ?? ""
                        let error = String(data: errorData, encoding: .utf8) ?? ""
                        
                        print("🔍 Process completed on background thread:")
                        print("   Exit code: \(task.terminationStatus)")
                        print("   Output length: \(output.count) chars")
                        
                        if task.terminationStatus == 0 && !output.isEmpty {
                            let lines = output.components(separatedBy: .newlines)
                                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            
                            if lines.count >= 3 {
                                let title = lines[0]
                                let durationStr = lines[1]
                                let thumbnail = lines[2]
                                
                                guard let duration = Double(durationStr) else {
                                    print("❌ Cannot parse duration: \(durationStr)")
                                    continuation.resume(throwing: YouTubeError.invalidVideoInfo)
                                    return
                                }
                                
                                let videoInfo = YouTubeVideoInfo(
                                    title: title,
                                    duration: duration,
                                    thumbnail: thumbnail,
                                    quality: "Unknown",
                                    url: urlString
                                )
                                
                                print("✅ Video info parsed successfully: \(title)")
                                continuation.resume(returning: videoInfo)
                            } else {
                                print("❌ Insufficient video info lines: \(lines.count)")
                                continuation.resume(throwing: YouTubeError.invalidVideoInfo)
                            }
                        } else {
                            print("❌ yt-dlp failed: \(error)")
                            continuation.resume(throwing: YouTubeError.downloadFailed)
                        }
                        
                    } catch {
                        print("❌ Failed to run yt-dlp: \(error)")
                        continuation.resume(throwing: YouTubeError.downloadFailed)
                    }
                }
            }
        }
    
    
    func downloadVideo(from urlString: String, progressCallback: @escaping (Double, String) -> Void) async throws -> URL {
        print("🎥 Starting YouTube download with smart progress...")

        let deps = dependenciesManager.checkDependencies()
        guard deps.ytdlp else {
            throw YouTubeError.ytDlpNotFound
        }

        // ✅ ProgressTracker pro lineární progress
        let progressTracker = ProgressTracker()
        let debouncer = ProgressDebouncer()
        await progressTracker.reset()

        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
            progressCallback(0.0, "Preparing download...")
        }
        
        let uniqueID = UUID().uuidString
        let baseFilename = "youtube_video_\(uniqueID)"
        let outputTemplate = tempDirectory.appendingPathComponent("\(baseFilename).%(ext)s").path
        
        guard let ytdlpPath = dependenciesManager.findExecutablePath(for: "yt-dlp") else {
            throw YouTubeError.ytDlpNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: ytdlpPath)
                
                // ✅ Správné argumenty pro MP4 bez recode-video
                task.arguments = [
                    "-f", "mp4[height>=2160]/mp4[height>=1440]/best[ext=mp4]/best",
                    "--no-playlist",
                    "--user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                    "--referer", "https://www.youtube.com/",
                    "-o", outputTemplate,
                    "--newline",
                    "--no-audio",
                    "--no-warnings",
                    "--retries", "3",
                    "--socket-timeout", "30",
                    urlString
                ]
                
                // Environment setup
                var environment = ProcessInfo.processInfo.environment
                environment["TMPDIR"] = NSTemporaryDirectory()
                environment["TEMP"] = NSTemporaryDirectory()
                environment["TMP"] = NSTemporaryDirectory()
                environment["PYINSTALLER_SEMAPHORE"] = "0"
                environment["PYI_DISABLE_SEMAPHORE"] = "1"
                environment["_PYI_SPLASH_IPC"] = "0"
                environment["OBJC_DISABLE_INITIALIZE_FORK_SAFETY"] = "YES"
                
                if let resourcePath = Bundle.main.resourcePath {
                    let currentPath = environment["PATH"] ?? ""
                    environment["PATH"] = "\(resourcePath):\(currentPath)"
                }
                task.environment = environment
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = errorPipe
                
                let outputCollector = OutputCollector()
                let errorCollector = OutputCollector()
                
                // ✅ OPRAVA: Task.detached pro async funkce
                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                        Task.detached {
                            await outputCollector.append(data)
                            
                            // ✅ parseNewLines s ProgressTracker
                            await self.parseNewLines(output, progressTracker: progressTracker, debouncer: debouncer, progressCallback: progressCallback)
                        }
                    }
                }
                
                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        Task.detached {
                            await errorCollector.append(data)
                        }
                    }
                }
                
                // ✅ KOMPLETNÍ terminationHandler
                task.terminationHandler = { task in
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    Task.detached { [weak self] in
                        guard let self = self else { return }
                        
                        if task.terminationStatus == 0 {
                            // ✅ Najdi stažené soubory
                            let downloadedFiles = await self.findDownloadedFiles(in: self.tempDirectory, matching: baseFilename)
                            
                            if let videoFile = downloadedFiles.first {
                                print("✅ Video downloaded: \(videoFile.lastPathComponent)")
                                
                                await MainActor.run {
                                    progressCallback(1.0, "Download completed")
                                }
                                
                                // ✅ KOMPLETNÍ codec flow
                                let videoProperties = await self.analyzeVideoProperties(videoFile)
                                print("📊 Video codec: \(videoProperties.codec)")
                                
                                if await self.isCodecCompatible(videoProperties.codec) {
                                    // ✅ H.264 kompatibilní - hotovo
                                    print("✅ Codec is compatible, no re-encoding needed")
                                    
                                    await MainActor.run {
                                        self.isDownloading = false
                                        self.downloadedVideoURL = videoFile
                                    }
                                    
                                    continuation.resume(returning: videoFile)
                                    
                                } else {
                                    // ✅ VP09/VP8 - potřeba konverze
                                    print("🔄 VP09 detected, converting to H.264...")
                                    
                                    await MainActor.run {
                                        progressCallback(-1, "Converting to H.264...")
                                    }
                                    
                                    do {
                                        let convertedURL = try await self.smartReEncodeToH264(videoFile, originalInfo: videoProperties) { progress, message in
                                            Task { @MainActor in
                                                if progress < 0 {
                                                    progressCallback(-1, message)
                                                } else {
                                                    // Konverze progress 80-100%
                                                    progressCallback(0.8 + (progress * 0.2), message)
                                                }
                                            }
                                        }
                                        
                                        print("✅ Re-encoding completed successfully")
                                        
                                        await MainActor.run {
                                            self.isDownloading = false
                                            self.downloadedVideoURL = convertedURL
                                            progressCallback(1.0, "Video optimized successfully!")
                                        }
                                        
                                        // Cleanup původní VP09 soubor
                                        try? FileManager.default.removeItem(at: videoFile)
                                        
                                        continuation.resume(returning: convertedURL)
                                        
                                    } catch {
                                        print("❌ Re-encoding failed: \(error)")
                                        
                                        await MainActor.run {
                                            self.isDownloading = false
                                        }
                                        
                                        continuation.resume(throwing: error)
                                    }
                                }
                            } else {
                                print("❌ Downloaded file not found")
                                
                                await MainActor.run {
                                    self.isDownloading = false
                                }
                                
                                continuation.resume(throwing: YouTubeError.fileNotFound)
                            }
                        } else {
                            print("❌ Download failed with exit code: \(task.terminationStatus)")
                            
                            let errorString = await errorCollector.getString()
                            print("Error output: \(errorString)")
                            
                            await MainActor.run {
                                self.isDownloading = false
                            }
                            
                            continuation.resume(throwing: YouTubeError.downloadFailed)
                        }
                    }
                }
                
                do {
                    try task.run()
                    
                    await MainActor.run {
                        self.downloadTask = task
                        // ✅ ŽÁDNÝ fake 5% progress
                    }
                    
                } catch {
                    print("❌ Failed to start download: \(error)")
                    
                    await MainActor.run {
                        self.isDownloading = false
                    }
                    
                    continuation.resume(throwing: YouTubeError.downloadFailed)
                }
            }
        }
    }
    

    private func parseNewLines(_ newOutput: String, progressTracker: ProgressTracker, debouncer: ProgressDebouncer, progressCallback: @escaping (Double, String) -> Void) async {
        
        let lines = newOutput.components(separatedBy: .newlines)
        
        for line in lines {
            // ✅ Zpracuj jen nové řádky
            guard await progressTracker.isNewLine(line) else { continue }
            
            // Parsuj download progress
            if line.contains("[download]") && line.contains("%") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                for component in components {
                    if component.contains("%") {
                        let percentString = component.replacingOccurrences(of: "%", with: "")
                        if let percent = Double(percentString), percent >= 0 && percent <= 100 {
                            let progress = percent / 100.0
                            let message = "Downloading: \(Int(percent))%"
                            
                            // ✅ Aktualizuj jen když je významná změna
                            if await progressTracker.shouldUpdate(progress: progress, message: message) {
                                await debouncer.scheduleUpdate(progress, message, callback: progressCallback)
                            }
                        }
                        break
                    }
                }
            }
        }
    }

    
    // MARK: - Helper Functions (nonisolated)
    private func parseTimeStringLocal(_ timeString: String) -> Double? {
        let components = timeString.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }
        
        var totalSeconds: Double = 0
        
        if components.count == 3 {
            // HH:MM:SS.ms format
            if let hours = Double(components[0]),
               let minutes = Double(components[1]),
               let seconds = Double(components[2]) {
                totalSeconds = hours * 3600 + minutes * 60 + seconds
            }
        } else if components.count == 2 {
            // MM:SS.ms format
            if let minutes = Double(components[0]),
               let seconds = Double(components[1]) {
                totalSeconds = minutes * 60 + seconds
            }
        }
        
        return totalSeconds > 0 ? totalSeconds : nil
    }
    
    
    // MARK: - Fixed Video Properties Function
    private func getBasicVideoInfo(from url: URL) async throws -> (duration: Double, resolution: CGSize) {
        guard let ffprobePath = dependenciesManager.findExecutablePath(for: "ffprobe") else {
            throw YouTubeError.ffmpegNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: ffprobePath)
                task.arguments = [
                    "-v", "quiet",
                    "-print_format", "json",
                    "-show_format",
                    "-show_streams",
                    url.path
                ]
                
                let outputPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = Pipe()
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    if task.terminationStatus == 0 {
                        // Parse JSON output
                        if let jsonData = output.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            
                            var duration: Double = 30.0 // Default fallback
                            var resolution = CGSize(width: 1920, height: 1080) // Default fallback
                            
                            // Get duration from format
                            if let format = json["format"] as? [String: Any],
                               let durationStr = format["duration"] as? String,
                               let parsedDuration = Double(durationStr) {
                                duration = parsedDuration
                            }
                            
                            // Get resolution from first video stream
                            if let streams = json["streams"] as? [[String: Any]] {
                                for stream in streams {
                                    if let codecType = stream["codec_type"] as? String, codecType == "video" {
                                        if let width = stream["width"] as? Int,
                                           let height = stream["height"] as? Int {
                                            resolution = CGSize(width: width, height: height)
                                            break
                                        }
                                    }
                                }
                            }
                            
                            continuation.resume(returning: (duration: duration, resolution: resolution))
                        } else {
                            // Fallback values
                            continuation.resume(returning: (duration: 30.0, resolution: CGSize(width: 1920, height: 1080)))
                        }
                    } else {
                        print("❌ ffprobe failed, using fallback values")
                        continuation.resume(returning: (duration: 30.0, resolution: CGSize(width: 1920, height: 1080)))
                    }
                } catch {
                    print("❌ ffprobe error: \(error), using fallback values")
                    continuation.resume(returning: (duration: 30.0, resolution: CGSize(width: 1920, height: 1080)))
                }
            }
        }
    }
    
    // MARK: - Get Video Duration Function
    private func getVideoDuration(from url: URL) async throws -> Double {
        guard let ffprobePath = dependenciesManager.findExecutablePath(for: "ffprobe") else {
            return 30.0 // fallback
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: ffprobePath)
                task.arguments = [
                    "-v", "quiet",
                    "-show_entries", "format=duration",
                    "-of", "csv=p=0",
                    url.path
                ]
                
                let outputPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = Pipe()
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    if let duration = Double(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        continuation.resume(returning: duration)
                    } else {
                        continuation.resume(returning: 30.0) // fallback
                    }
                } catch {
                    continuation.resume(returning: 30.0) // fallback
                }
            }
        }
    }

    
    // MARK: - Enhanced trimVideo with runtime fixes
    func trimVideo(_ inputURL: URL, startTime: Double, endTime: Double, outputPath: URL) async throws {
        print("✂️ Enhanced trimming video: \(startTime)s to \(endTime)s")
        
        // KROK 1: Ensure tools are executable (runtime fix)
        //await ensureToolsAreExecutable()
        
        // KROK 2: Find ffmpeg
        guard let ffmpegPath = dependenciesManager.findExecutablePath(for: "ffmpeg") else {
            print("❌ FFmpeg not found after runtime fix")
            throw YouTubeError.ffmpegNotFound
        }
        
        print("🔧 Using ffmpeg at: \(ffmpegPath)")
        

        let duration = endTime - startTime
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
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
                
                print("🔧 FFmpeg command: \(task.arguments?.joined(separator: " ") ?? "")")
                
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
                        // Read error output for debugging
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                        
                        print("❌ Trimming failed with exit code: \(task.terminationStatus)")
                        print("❌ FFmpeg error: \(errorOutput)")
                        
                        continuation.resume(throwing: YouTubeError.processingFailed)
                    }
                } catch {
                    print("❌ Failed to start trimming: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func analyzeVideoProperties(_ videoURL: URL) async -> VideoProperties {
        // ✅ OPRAVA: Použít DependenciesManager místo ExecutableManager
        guard let ffmpegPath = dependenciesManager.findExecutablePath(for: "ffmpeg") else {
            print("❌ FFmpeg not found for video analysis")
            return VideoProperties(
                duration: 0,
                resolution: CGSize(width: 1920, height: 1080),
                videoTracks: 0,
                audioTracks: 0,
                codec: "unknown",
                isPlayable: false
            )
        }
        
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ffmpegPath)
            
            task.arguments = [
                "-i", videoURL.path,
                "-f", "null",
                "-"
            ]
            
            let pipe = Pipe()
            task.standardError = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                let properties = parseVideoInfo(output)
                continuation.resume(returning: properties)
                
            } catch {
                print("❌ Failed to analyze video: \(error)")
                continuation.resume(returning: VideoProperties(
                    duration: 0,
                    resolution: CGSize(width: 1920, height: 1080),
                    videoTracks: 0,
                    audioTracks: 0,
                    codec: "unknown",
                    isPlayable: false
                ))
            }
        }
    }
    
    
    private func parseVideoInfo(_ output: String) -> VideoProperties {
        var duration: Double = 0
        var width: Int = 1920
        var height: Int = 1080
        var videoTracks = 0
        var audioTracks = 0
        var codec = "unknown"
        
        // Parse duration
        if let durationRange = output.range(of: "Duration: ") {
            let afterDuration = String(output[durationRange.upperBound...])
            if let commaRange = afterDuration.range(of: ",") {
                let durationString = String(afterDuration[..<commaRange.lowerBound])
                duration = parseDurationString(durationString)
            }
        }
        
        // Parse video stream info
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Video:") {
                videoTracks += 1
                
                // Parse codec
                if let videoRange = line.range(of: "Video: ") {
                    let afterVideo = String(line[videoRange.upperBound...])
                    if let spaceRange = afterVideo.range(of: " ") {
                        codec = String(afterVideo[..<spaceRange.lowerBound])
                    }
                }
                
                // Parse resolution
                let resolutionPattern = "([0-9]+)x([0-9]+)"
                if let regex = try? NSRegularExpression(pattern: resolutionPattern, options: []) {
                    let nsString = line as NSString
                    let results = regex.matches(in: line, options: [], range: NSMakeRange(0, nsString.length))
                    
                    if let match = results.first, match.numberOfRanges > 2 {
                        if let w = Int(nsString.substring(with: match.range(at: 1))),
                           let h = Int(nsString.substring(with: match.range(at: 2))) {
                            width = w
                            height = h
                        }
                    }
                }
            } else if line.contains("Audio:") {
                audioTracks += 1
            }
        }
        
        return VideoProperties(
            duration: duration,
            resolution: CGSize(width: width, height: height),
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            codec: codec,
            isPlayable: videoTracks > 0
        )
    }
    
    private func isCodecCompatible(_ codec: String) -> Bool {
        let compatibleCodecs = ["avc1", "h264", "mp4v"]
        return compatibleCodecs.contains { compatibleCodec in
            codec.lowercased().contains(compatibleCodec.lowercased())
        }
    }
    
    // ✅ OPRAVENÁ: smartReEncodeToH264 s background thread
        func smartReEncodeToH264(_ inputURL: URL, originalInfo: VideoProperties, progressCallback: @escaping (Double, String) -> Void) async throws -> URL {
            let outputURL = tempDirectory.appendingPathComponent("h264_\(UUID().uuidString).mp4")
            
            print("🔄 Re-encoding started: \(Int(originalInfo.resolution.width))x\(Int(originalInfo.resolution.height))")
            
            let deps = dependenciesManager.checkDependencies()
            guard deps.ffmpeg else {
                throw YouTubeError.ffmpegNotFound
            }
            
            guard let ffmpegPath = dependenciesManager.findExecutablePath(for: "ffmpeg") else {
                throw YouTubeError.ffmpegNotFound
            }
            
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                // ✅ FFmpeg na background thread
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
                    
                    let outputCollector = OutputCollector()
                    let errorCollector = OutputCollector()
                    
                    outputPipe.fileHandleForReading.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty {
                            let output = String(data: data, encoding: .utf8) ?? ""
                            
                            Task {
                                await outputCollector.append(data)
                            }
                            
                            // ✅ Progress update na main thread
                            Task { @MainActor in
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
                        
                        if task.terminationStatus == 0 && FileManager.default.fileExists(atPath: outputURL.path) {
                            print("✅ Re-encoding completed successfully")
                            continuation.resume(returning: outputURL)
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
                        continuation.resume(throwing: YouTubeError.processingFailed)
                    }
                }
            }
        }

        
    
    // MARK: - Helper Methods
    
    private func parseDurationString(_ durationString: String) -> Double {
        let components = durationString.components(separatedBy: ":")
        guard components.count == 3 else { return 0 }
        
        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return 0
        }
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    private func findDownloadedFiles(in directory: URL, matching pattern: String) async -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            return files.filter { $0.lastPathComponent.contains(pattern) && $0.pathExtension == "mp4" }
        } catch {
            print("❌ Error reading directory: \(error)")
            return []
        }
    }
    
    // 2. ✅ UPRAVENÝ parseDownloadProgress - jasné rozlišení fází
    private func parseDownloadProgress(_ output: String, progressCallback: @escaping (Double, String) -> Void) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // Standard download progress
            if line.contains("[download]") && line.contains("%") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                for component in components {
                    if component.contains("%") {
                        let percentString = component.replacingOccurrences(of: "%", with: "")
                        if let percent = Double(percentString) {
                            let progress = percent / 100.0
                            
                            // ✅ KLÍČOVÁ ZMĚNA: Jakmile dosáhneme 100%, hned přejdeme na "Download completed"
                            if progress >= 1.0 {
                                progressCallback(1.0, "Download completed")
                                // Další zpráva "Getting video info..." se zobrazí v terminationHandler
                            } else {
                                let message = "Downloading: \(Int(percent))%"
                                progressCallback(progress, message)
                            }
                        }
                        break
                    }
                }
            }
            
            // Detect conversion/merger phase
            if line.contains("[Merger]") || line.contains("muxing") {
                progressCallback(-1, "Finalizing download...")
                print("🔄 Download finalization phase")
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
                        if match.numberOfRanges > 1 {
                            let timeString = nsString.substring(with: match.range(at: 1))
                            if let currentTime = parseTimeString(timeString), totalDuration > 0 {
                                let progress = min(currentTime / totalDuration, 1.0)
                                
                                DispatchQueue.main.async {
                                    let percentage = Int(progress * 100)
                                    progressCallback(progress, "Converting: \(percentage)%")
                                }
                                return
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func parseTimeString(_ timeString: String) -> Double? {
        let components = timeString.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }
        
        var totalSeconds: Double = 0
        
        if components.count == 3 {
            // HH:MM:SS.ms format
            if let hours = Double(components[0]),
               let minutes = Double(components[1]),
               let seconds = Double(components[2]) {
                totalSeconds = hours * 3600 + minutes * 60 + seconds
            }
        } else if components.count == 2 {
            // MM:SS.ms format
            if let minutes = Double(components[0]),
               let seconds = Double(components[1]) {
                totalSeconds = minutes * 60 + seconds
            }
        }
        
        return totalSeconds > 0 ? totalSeconds : nil
    }
    
    private func parseTimeToSeconds(_ timeString: String) -> Double {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 3 else { return 0 }
        
        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return 0
        }
        
        // ✅ Validace rozumných hodnot
        guard hours >= 0 && hours < 24,
              minutes >= 0 && minutes < 60,
              seconds >= 0 && seconds < 60 else {
            return 0
        }
        
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
    case downloadError(String)  // ✅ PŘIDEJTE TENTO
    case parsingError           // ✅ PŘIDEJTE TENTO
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
        case .downloadError(let message):  // ✅ PŘIDEJTE TENTO
            return "Download error: \(message)"
        case .parsingError:                // ✅ PŘIDEJTE TENTO
            return "Failed to parse video information"
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


actor ProgressTracker {
    private var lastProgress: Double = -1
    private var lastMessage: String = ""
    private var processedLines: Set<String> = []
    
    func shouldUpdate(progress: Double, message: String) -> Bool {
        // Aktualizuj jen když je výrazná změna nebo nová zpráva
        let progressChanged = abs(progress - lastProgress) >= 0.01 // 1% change
        let messageChanged = message != lastMessage
        
        if progressChanged || messageChanged {
            lastProgress = progress
            lastMessage = message
            return true
        }
        return false
    }
    
    func isNewLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        if processedLines.contains(trimmed) {
            return false
        } else {
            processedLines.insert(trimmed)
            return true
        }
    }
    
    func reset() {
        lastProgress = -1
        lastMessage = ""
        processedLines.removeAll()
    }
}

actor ProgressDebouncer {
    private var pendingUpdate: (Double, String)?
    private var debounceTimer: Task<Void, Never>?
    
    func scheduleUpdate(_ progress: Double, _ message: String, callback: @escaping (Double, String) -> Void) {
        // Zruš předchozí timer
        debounceTimer?.cancel()
        
        // Pro důležité zprávy (100%, completion) pošli okamžitě
        if progress >= 1.0 || message.contains("completed") || message.contains("failed") {
            Task { @MainActor in
                callback(progress, message)
            }
            return
        }
        
        // Pro ostatní použij debouncing
        pendingUpdate = (progress, message)
        
        debounceTimer = Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            if let update = pendingUpdate {
                Task { @MainActor in
                    callback(update.0, update.1)
                }
                pendingUpdate = nil
            }
        }
    }
}
