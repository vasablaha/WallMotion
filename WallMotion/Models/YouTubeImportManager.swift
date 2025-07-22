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
    // ✅ OPRAVENÁ FUNKCE: Používá DependenciesManager
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
        print("🎥 Starting YouTube download on background thread...")

        let deps = dependenciesManager.checkDependencies()
        guard deps.ytdlp else {
            throw YouTubeError.ytDlpNotFound
        }

        // ✅ UI update na main thread
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
        }
        
        let uniqueID = UUID().uuidString
        let baseFilename = "youtube_video_\(uniqueID)"
        let outputTemplate = tempDirectory.appendingPathComponent("\(baseFilename).%(ext)s").path
        
        guard let ytdlpPath = dependenciesManager.findExecutablePath(for: "yt-dlp") else {
            throw YouTubeError.ytDlpNotFound
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            // ✅ Process na background thread
            Task.detached {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: ytdlpPath)
                
                task.arguments = [
                    "-f", "bestvideo[ext=mp4][height<=1080]/bestvideo[height<=1080]/bestvideo[ext=mp4]/bestvideo",
                    "--merge-output-format", "mp4",
                    "-o", outputTemplate,
                    "--no-playlist",
                    "--newline",
                    "--no-warnings",
                    "--no-check-certificate",
                    "--retries", "3",
                    "--socket-timeout", "30",
                    "--force-ipv4",
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
                
                // Monitor progress on background thread
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
                            self.parseDownloadProgress(output, progressCallback: progressCallback)
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
                        Task { @MainActor in
                            let mp4Files = self.findDownloadedFiles(in: self.tempDirectory, matching: baseFilename)
                            
                            if let videoFile = mp4Files.first {
                                print("✅ Video downloaded: \(videoFile.lastPathComponent)")
                                
                                // Check if we need to re-encode (on background thread)
                                Task.detached {
                                    let videoProperties = await self.analyzeVideoProperties(videoFile)
                                    print("📊 Video info: \(videoProperties.qualityDescription), \(videoProperties.codec)")
                                    
                                    await MainActor.run {
                                        if self.isCodecCompatible(videoProperties.codec) {
                                            print("✅ Codec is compatible, no re-encoding needed")
                                            self.isDownloading = false
                                            self.downloadedVideoURL = videoFile
                                            continuation.resume(returning: videoFile)
                                        } else {
                                            print("🔄 Re-encoding needed...")
                                            progressCallback(0.0, "Converting to H.264 codec...")
                                            
                                            Task {
                                                do {
                                                    let reEncodedURL = try await self.smartReEncodeToH264(
                                                        videoFile,
                                                        originalInfo: videoProperties,
                                                        progressCallback: progressCallback
                                                    )
                                                    
                                                    await MainActor.run {
                                                        print("✅ Re-encoding completed successfully")
                                                        self.isDownloading = false
                                                        self.downloadedVideoURL = reEncodedURL
                                                        continuation.resume(returning: reEncodedURL)
                                                    }
                                                } catch {
                                                    await MainActor.run {
                                                        print("❌ Re-encoding failed: \(error)")
                                                        self.isDownloading = false
                                                        continuation.resume(throwing: error)
                                                    }
                                                }
                                            }
                                        }
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
                            
                            await MainActor.run {
                                self.isDownloading = false
                                continuation.resume(throwing: YouTubeError.downloadFailed)
                            }
                        }
                    }
                }
                
                do {
                    try task.run()
                    
                    // ✅ Store download task na main thread
                    await MainActor.run {
                        self.downloadTask = task
                        progressCallback(0.05, "Starting download...")
                    }
                    
                } catch {
                    print("❌ Failed to start download: \(error)")
                    
                    await MainActor.run {
                        self.isDownloading = false
                        continuation.resume(throwing: YouTubeError.downloadFailed)
                    }
                }
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


extension YouTubeImportManager {
    // MARK: - Enhanced Error Handling & Debugging

    // ✅ OPRAVENÁ FUNKCE: Používá DependenciesManager paths
        func testBundledTools() async -> (success: Bool, details: String) {
            var results = "🧪 Testing Tools via DependenciesManager:\n"
            results += "========================================\n\n"
            
            // Test yt-dlp
            if let ytdlpPath = dependenciesManager.findExecutablePath(for: "yt-dlp") {
                results += "📺 Testing yt-dlp at: \(ytdlpPath)\n"
                
                // Check file properties
                let fileManager = FileManager.default
                let isExecutable = fileManager.isExecutableFile(atPath: ytdlpPath)
                let fileExists = fileManager.fileExists(atPath: ytdlpPath)
                
                results += "  • File exists: \(fileExists ? "✅" : "❌")\n"
                results += "  • Is executable: \(isExecutable ? "✅" : "❌")\n"
                
                // Try to get file attributes
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: ytdlpPath)
                    if let permissions = attributes[.posixPermissions] as? NSNumber {
                        results += "  • Permissions: \(String(permissions.uint16Value, radix: 8))\n"
                    }
                    if let size = attributes[.size] as? NSNumber {
                        results += "  • File size: \(size.intValue) bytes\n"
                    }
                } catch {
                    results += "  • Error reading attributes: \(error)\n"
                }
                
                // Try to run version check
                let (versionSuccess, versionOutput) = await testToolVersion(path: ytdlpPath, args: ["--version"])
                results += "  • Version test: \(versionSuccess ? "✅" : "❌")\n"
                if !versionOutput.isEmpty {
                    results += "  • Output: \(versionOutput.prefix(100))\n"
                }
                
                results += "\n"
            } else {
                results += "❌ yt-dlp path not found via DependenciesManager\n\n"
            }
            
            // Test ffmpeg
            if let ffmpegPath = dependenciesManager.findExecutablePath(for: "ffmpeg") {
                results += "🎬 Testing ffmpeg at: \(ffmpegPath)\n"
                
                let fileManager = FileManager.default
                let isExecutable = fileManager.isExecutableFile(atPath: ffmpegPath)
                let fileExists = fileManager.fileExists(atPath: ffmpegPath)
                
                results += "  • File exists: \(fileExists ? "✅" : "❌")\n"
                results += "  • Is executable: \(isExecutable ? "✅" : "❌")\n"
                
                // Try to get file attributes
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: ffmpegPath)
                    if let permissions = attributes[.posixPermissions] as? NSNumber {
                        results += "  • Permissions: \(String(permissions.uint16Value, radix: 8))\n"
                    }
                    if let size = attributes[.size] as? NSNumber {
                        results += "  • File size: \(size.intValue) bytes\n"
                    }
                } catch {
                    results += "  • Error reading attributes: \(error)\n"
                }
                
                // Try to run version check
                let (versionSuccess, versionOutput) = await testToolVersion(path: ffmpegPath, args: ["-version"])
                results += "  • Version test: \(versionSuccess ? "✅" : "❌")\n"
                if !versionOutput.isEmpty {
                    results += "  • Output: \(versionOutput.prefix(100))\n"
                }
                
                results += "\n"
            } else {
                results += "❌ ffmpeg path not found via DependenciesManager\n\n"
            }
            
            // Overall success
            let ytdlpFound = dependenciesManager.findExecutablePath(for: "yt-dlp") != nil
            let ffmpegFound = dependenciesManager.findExecutablePath(for: "ffmpeg") != nil
            let overallSuccess = ytdlpFound && ffmpegFound
            
            results += "📊 Overall Status: \(overallSuccess ? "✅ SUCCESS" : "❌ FAILED")\n"
            results += "🔧 Using DependenciesManager for path resolution\n"
            
            return (success: overallSuccess, details: results)
        }

    private func testToolVersion(path: String, args: [String]) async -> (success: Bool, output: String) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: path)
                task.arguments = args
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = errorPipe
                
                // Set timeout
                var completed = false
                DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                    if !completed {
                        task.terminate()
                    }
                }
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    completed = true
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    
                    let combinedOutput = !output.isEmpty ? output : error
                    let success = task.terminationStatus == 0
                    
                    continuation.resume(returning: (success, combinedOutput))
                } catch {
                    completed = true
                    continuation.resume(returning: (false, "Failed to run: \(error)"))
                }
            }
        }
    }

    // Enhanced getVideoInfo with better error reporting
    func getVideoInfoWithDebugging(from urlString: String) async throws -> YouTubeVideoInfo {
        print("📋 Getting video info for: \(urlString)")
        
        guard validateYouTubeURL(urlString) else {
            print("❌ Invalid YouTube URL")
            throw YouTubeError.invalidURL
        }
        
        // Check if yt-dlp exists
        let deps = dependenciesManager.checkDependencies()
        guard deps.ytdlp else {
            print("❌ yt-dlp not found in dependency check")
            
            // Enhanced debugging
            print("🔍 Running detailed tool check...")
            let (toolsWork, toolDetails) = await testBundledTools()
            print("Tool test results:\n\(toolDetails)")
            
            throw YouTubeError.ytDlpNotFound
        }
        
        guard let ytdlpPath = dependenciesManager.findExecutablePath(for: "yt-dlp") else {
            print("❌ yt-dlp path not found")
            throw YouTubeError.ytDlpNotFound
        }
        
        print("✅ Found yt-dlp at: \(ytdlpPath)")
        
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
            
            // Enhanced environment setup
            var environment = ProcessInfo.processInfo.environment
            // Add bundle Resources to PATH in case tools need it
            if let resourcePath = Bundle.main.resourcePath {
                let bundlePath = "\(resourcePath)"
                let currentPath = environment["PATH"] ?? ""
                environment["PATH"] = "\(bundlePath):\(currentPath)"
            }
            task.environment = environment
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            print("🚀 Starting yt-dlp process...")
            print("   Command: \(ytdlpPath) \(task.arguments?.joined(separator: " ") ?? "")")
            print("   Environment PATH: \(environment["PATH"] ?? "Not set")")
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""
                
                print("🔍 Process completed:")
                print("   Exit code: \(task.terminationStatus)")
                print("   Output length: \(output.count) chars")
                print("   Error length: \(error.count) chars")
                
                if !error.isEmpty {
                    print("   Error output: \(error.prefix(500))")
                }
                
                if task.terminationStatus == 0 && !output.isEmpty {
                    let lines = output.components(separatedBy: .newlines)
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    
                    print("   Parsed lines: \(lines.count)")
                    
                    if lines.count >= 3 {
                        let title = lines[0]
                        let duration = Double(lines[1]) ?? 0
                        let thumbnail = lines[2]
                        
                        let videoInfo = YouTubeVideoInfo(
                            title: title,
                            duration: duration,
                            thumbnail: thumbnail,
                            quality: "Unknown",
                            url: urlString
                        )
                        
                        print("✅ Successfully parsed video info:")
                        print("   Title: \(title)")
                        print("   Duration: \(duration)s")
                        
                        continuation.resume(returning: videoInfo)
                        return
                    }
                }
                
                let errorString = !error.isEmpty ? error : "No output from yt-dlp"
                print("❌ Info retrieval failed: \(errorString)")
                continuation.resume(throwing: YouTubeError.invalidVideoInfo)
                
            } catch {
                print("❌ Failed to start yt-dlp process: \(error)")
                
                // Additional debugging for process start failure
                if let nsError = error as NSError? {
                    print("   Error domain: \(nsError.domain)")
                    print("   Error code: \(nsError.code)")
                    print("   Error description: \(nsError.localizedDescription)")
                    
                    if nsError.code == 13 {
                        print("   ⚠️ This is a permissions error (EACCES)")
                    } else if nsError.code == 2 {
                        print("   ⚠️ This is a 'file not found' error (ENOENT)")
                    }
                }
                
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Fix bundled tool permissions

    func fixBundledToolPermissions() async -> Bool {
        print("🔧 Fixing bundled tool permissions...")
        
        let tools = ["yt-dlp", "ffmpeg"]
        var allFixed = true
        
        for tool in tools {
            if let toolPath = dependenciesManager.findExecutablePath(for: tool),
               toolPath.contains("Contents/Resources") { // Only fix bundled tools
                
                print("🔧 Fixing permissions for: \(toolPath)")
                
                let (success, output) = await runChmodCommand(path: toolPath)
                if success {
                    print("   ✅ Permissions fixed")
                } else {
                    print("   ❌ Failed to fix permissions: \(output)")
                    allFixed = false
                }
            }
        }
        
        return allFixed
    }

    private func runChmodCommand(path: String) async -> (success: Bool, output: String) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/chmod")
                task.arguments = ["+x", path]
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = errorPipe
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    
                    let success = task.terminationStatus == 0
                    let combinedOutput = !error.isEmpty ? error : output
                    
                    continuation.resume(returning: (success, combinedOutput))
                } catch {
                    continuation.resume(returning: (false, "chmod failed: \(error)"))
                }
            }
        }
    }
}
