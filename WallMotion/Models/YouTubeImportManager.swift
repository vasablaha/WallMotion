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
            
            // Používáme separátní print příkazy pro každou informaci
            task.arguments = [
                "--print", "%(title)s",
                "--print", "%(duration)s",
                "--print", "%(thumbnail)s",
                "--no-download",
                "--no-warnings",
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
                    print("📄 Raw output lines:")
                    
                    // Parse line by line
                    let lines = output.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    
                    print("📋 Parsed \(lines.count) lines: \(lines)")
                    
                    var title = "Unknown Title"
                    var duration: Double = 0.0
                    var thumbnail = ""
                    
                    // Parse individual lines
                    if lines.count >= 1 {
                        title = lines[0]
                        print("   📝 Title: '\(title)'")
                    }
                    
                    if lines.count >= 2 {
                        let durationStr = lines[1]
                        if let durationValue = Double(durationStr) {
                            duration = durationValue
                        }
                        print("   ⏱️ Duration: '\(durationStr)' -> \(duration)s")
                    }
                    
                    if lines.count >= 3 {
                        thumbnail = lines[2]
                        print("   🖼️ Thumbnail: '\(thumbnail)'")
                    }
                    
                    // Pro určení kvality, spustíme rychlý test formátů
                    let quality = "Video available" // Defaultní hodnota - detailnější kontrola by vyžadovala další yt-dlp call
                    
                    let videoInfo = YouTubeVideoInfo(
                        title: title,
                        duration: duration,
                        thumbnail: thumbnail,
                        quality: quality,
                        url: urlString
                    )
                    
                    print("✅ Video info parsed successfully:")
                    print("   📝 Final Title: \(title)")
                    print("   ⏱️ Final Duration: \(duration)s")
                    print("   🎬 Quality: \(quality)")
                    
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
        print("📍 Temp directory: \(tempDirectory.path)")
        
        isDownloading = true
        downloadProgress = 0.0
        
        // Create unique filename without extension placeholder
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
            
            // Optimalizované argumenty bez FFmpeg závislých funkcí
            task.arguments = [
                // Format selector s podporou až 4K (2160p) + fallbacky
                "-f", "best[ext=mp4][height>=1080]/best[ext=mp4][height>=720]/best[ext=mp4]/bestvideo[height>=2160][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height>=1440][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height>=1080][ext=mp4]+bestaudio[ext=m4a]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/best",

                
                "--merge-output-format", "mp4",
                "-o", outputTemplate,
                "--no-playlist",
                "--newline",
                "--no-warnings",
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
                    print("📥 STDOUT: \(output)")
                    self.parseDownloadProgress(output, progressCallback: progressCallback)
                }
            }
            
            // Monitor stderr
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    allErrors += output
                    print("🔍 STDERR: \(output)")
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
                        print("📄 Full output: \(allOutput)")
                        print("❗ Full errors: \(allErrors)")
                        
                        if task.terminationStatus == 0 {
                            // Find downloaded file
                            print("🔍 Looking for downloaded file with base: \(baseFilename)")
                            let downloadedFile = self.findDownloadedFile(baseFilename: baseFilename, inDirectory: self.tempDirectory)
                            
                            if let fileURL = downloadedFile {
                                print("✅ Found downloaded file: \(fileURL.path)")
                                
                                // Základní verifikace souboru bez FFmpeg
                                self.verifyVideoFileBasic(at: fileURL) { isValid in
                                    if isValid {
                                        print("✅ Video file verification passed")
                                        self.downloadedVideoURL = fileURL
                                        continuation.resume(returning: fileURL)
                                    } else {
                                        print("❌ Downloaded file is not valid")
                                        continuation.resume(throwing: YouTubeError.downloadFailed)
                                    }
                                }
                            } else {
                                print("❌ Downloaded file not found!")
                                print("📁 Temp directory contents:")
                                self.listDirectoryContents(self.tempDirectory)
                                continuation.resume(throwing: YouTubeError.fileNotFound)
                            }
                        } else {
                            print("❌ Download failed with exit code: \(task.terminationStatus)")
                            
                            // Analyzuj chyby pro lepší diagnostiku
                            if allErrors.contains("ffmpeg not found") {
                                print("💡 FFmpeg not found - this is expected and OK")
                                print("💡 Checking if video file was still downloaded...")
                                
                                // I přes FFmpeg chybu se soubor mohl stáhnout
                                let downloadedFile = self.findDownloadedFile(baseFilename: baseFilename, inDirectory: self.tempDirectory)
                                if let fileURL = downloadedFile {
                                    print("✅ Video file was downloaded despite FFmpeg error!")
                                    self.downloadedVideoURL = fileURL
                                    continuation.resume(returning: fileURL)
                                    return
                                }
                            }
                            
                            if allErrors.contains("audio only") || allErrors.contains("no video") {
                                print("💡 Detected audio-only issue - trying fallback format")
                            }
                            
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
                "-ss", String(startTime),
                "-t", String(duration),
                "-c", "copy",
                "-avoid_negative_ts", "make_zero",
                "-y",
                outputPath.path
            ]
            
            print("🚀 Executing: \(ffmpegPath) \(task.arguments!.joined(separator: " "))")
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                print("🏁 FFmpeg finished with status: \(task.terminationStatus)")
                
                if task.terminationStatus == 0 {
                    // Verify output file was created and has content
                    if FileManager.default.fileExists(atPath: outputPath.path) {
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: outputPath.path)
                            if let fileSize = attributes[.size] as? Int64 {
                                print("✅ Trimmed video created: \(outputPath.path) (\(fileSize) bytes)")
                                continuation.resume()
                            } else {
                                print("❌ Output file has no size information")
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
                    continuation.resume(throwing: YouTubeError.processingFailed)
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
                                progressCallback(progress, "Downloading video... \(Int(percent))%")
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
        print("📁 In directory: \(directory.path)")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            print("📄 All files in directory: \(files)")
            
            // Look for files that start with our base filename
            let matchingFiles = files.filter { $0.hasPrefix(baseFilename) }
            print("🎯 Matching files: \(matchingFiles)")
            
            if let firstMatch = matchingFiles.first {
                let fullPath = directory.appendingPathComponent(firstMatch)
                print("✅ Selected file: \(fullPath.path)")
                
                // Verify file exists and has content
                let attributes = try FileManager.default.attributesOfItem(atPath: fullPath.path)
                if let fileSize = attributes[.size] as? Int64 {
                    print("📏 File size: \(fileSize) bytes")
                    if fileSize > 0 {
                        return fullPath
                    } else {
                        print("❌ File is empty!")
                    }
                }
            }
        } catch {
            print("❌ Error reading directory: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Basic Video File Verification (without FFmpeg)
    
    private func verifyVideoFileBasic(at url: URL, completion: @escaping (Bool) -> Void) {
        print("🔍 Basic verification of video file: \(url.path)")
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                print("📏 File size: \(fileSize) bytes")
                
                // Základní kontroly:
                // 1. Soubor musí existovat a mít nenulovou velikost
                guard fileSize > 0 else {
                    print("❌ File is empty")
                    completion(false)
                    return
                }
                
                // 2. Musí být větší než 100KB (velmi malé soubory jsou pravděpodobně chybové)
                guard fileSize > 100_000 else {
                    print("❌ File too small (\(fileSize) bytes) - likely error file")
                    completion(false)
                    return
                }
                
                // 3. Kontrola přípony souboru
                let fileExtension = url.pathExtension.lowercased()
                let validExtensions = ["mp4", "webm", "mkv", "avi", "mov"]
                
                guard validExtensions.contains(fileExtension) else {
                    print("❌ Invalid file extension: .\(fileExtension)")
                    completion(false)
                    return
                }
                
                print("✅ Basic verification passed:")
                print("   📏 Size: \(fileSize) bytes (\(String(format: "%.2f", Double(fileSize) / 1_000_000)) MB)")
                print("   📄 Extension: .\(fileExtension)")
                
                completion(true)
                
            } else {
                print("❌ Could not get file size")
                completion(false)
            }
        } catch {
            print("❌ Error checking file attributes: \(error)")
            completion(false)
        }
    }
    
    // MARK: - Video File Verification (with FFmpeg - original method)
    
    private func verifyVideoFile(at url: URL, completion: @escaping (Bool) -> Void) {
        print("🔍 Verifying video file: \(url.path)")
        
        // Kontrola pomocí ffprobe (pokud je dostupný)
        let ffprobePaths = ["/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe", "/usr/bin/ffprobe"]
        guard let ffprobePath = ffprobePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("⚠️ ffprobe not found, skipping detailed verification")
            // Základní kontrola velikosti souboru
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? Int64 {
                    print("📏 File size: \(fileSize) bytes")
                    // Pokud je soubor větší než 1MB, pravděpodobně obsahuje video
                    completion(fileSize > 1_000_000)
                    return
                }
            } catch {
                print("❌ Error checking file attributes: \(error)")
            }
            completion(false)
            return
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: ffprobePath)
        task.arguments = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_streams",
            url.path
        ]
        
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8),
                   let jsonData = output.data(using: .utf8) {
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let streams = json["streams"] as? [[String: Any]] {
                            
                            let hasVideo = streams.contains { stream in
                                (stream["codec_type"] as? String) == "video"
                            }
                            
                            let hasAudio = streams.contains { stream in
                                (stream["codec_type"] as? String) == "audio"
                            }
                            
                            print("📊 File analysis: Video streams: \(hasVideo), Audio streams: \(hasAudio)")
                            completion(hasVideo) // Soubor musí obsahovat video stream
                            return
                        }
                    } catch {
                        print("❌ Error parsing ffprobe output: \(error)")
                    }
                }
            }
        } catch {
            print("❌ Error running ffprobe: \(error)")
        }
        
        // Fallback na základní kontrolu
        completion(true)
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
        let ytdlpPaths = ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp", "/usr/bin/yt-dlp"]
        let ytdlpExists = ytdlpPaths.contains { FileManager.default.fileExists(atPath: $0) }
        
        let ffmpegPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        let ffmpegExists = ffmpegPaths.contains { FileManager.default.fileExists(atPath: $0) }
        
        print("🔍 Dependency check:")
        print("   yt-dlp: \(ytdlpExists ? "✅" : "❌") (checked: \(ytdlpPaths))")
        print("   ffmpeg: \(ffmpegExists ? "✅" : "❌") (checked: \(ffmpegPaths))")
        
        return (ytdlp: ytdlpExists, ffmpeg: ffmpegExists)
    }
    
    func installationInstructions() -> String {
        let deps = checkDependencies()
        var instructions: [String] = []
        
        if !deps.ytdlp {
            instructions.append("brew install yt-dlp")
        }
        
        if !deps.ffmpeg {
            instructions.append("brew install ffmpeg")
        }
        
        if instructions.isEmpty {
            return "All dependencies are installed! ✅"
        } else {
            var message = "Please install missing dependencies:\n\n"
            message += instructions.joined(separator: "\n")
            
            if !deps.ffmpeg {
                message += "\n\nNote: FFmpeg is optional but recommended for:"
                message += "\n• Thumbnail conversion"
                message += "\n• Metadata embedding"
                message += "\n• Advanced video processing"
                message += "\n\nBasic video download will work without FFmpeg."
            }
            
            return message
        }
    }
}
