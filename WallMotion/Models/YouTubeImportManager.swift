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
    
    // Updated downloadVideo function to force H.264 for AVPlayer compatibility

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
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ytdlpPath)
            
            // POUZE TVŮJ PŮVODNÍ -F TAG - žádné další úpravy!
            task.arguments = [
                // Tvůj původní formát - ZACHOVÁVÁME PŘESNĚ!
                "-f", "bestvideo[ext=mp4][height<=2160]/bestvideo[height<=2160]/bestvideo[ext=mp4]/bestvideo",
                
                // Základní nastavení
                "--merge-output-format", "mp4",
                "-o", outputTemplate,
                "--no-playlist",
                "--newline",
                "--no-warnings",
                
                // Timeouts
                "--retries", "3",
                "--socket-timeout", "30",
                
                // Force IPv4
                "--force-ipv4",
                
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
                    print("📥 STDERR: \(output)")
                }
            }
            
            do {
                try task.run()
                task.waitUntilExit()
                
                // Stop monitoring pipes
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                print("🏁 Download task finished with status: \(task.terminationStatus)")
                
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.downloadProgress = 1.0
                    progressCallback(1.0, "Download completed")
                }
                
                if task.terminationStatus == 0 {
                    // Find downloaded file
                    let downloadedFile = self.findBestDownloadedFile(baseFilename: baseFilename, inDirectory: self.tempDirectory)
                    
                    if let fileURL = downloadedFile {
                        print("✅ Download successful: \(fileURL.path)")
                        
                        // Verify codec - POUZE pokud není kompatibilní, pak re-encode
                        Task {
                            do {
                                let videoInfo = try await self.getVideoProperties(at: fileURL)
                                print("🎬 Downloaded video properties: \(videoInfo)")
                                
                                // Check if codec is compatible with AVPlayer
                                if self.isCodecCompatible(videoInfo.codec) {
                                    print("✅ Codec \(videoInfo.codec) is compatible - using as-is")
                                    await MainActor.run {
                                        self.downloadedVideoURL = fileURL
                                    }
                                    continuation.resume(returning: fileURL)
                                } else {
                                    print("⚠️ Codec \(videoInfo.codec) is NOT compatible - re-encoding to H.264...")
                                    print("   Original resolution: \(Int(videoInfo.resolution.width))x\(Int(videoInfo.resolution.height))")
                                    let reEncodedURL = try await self.smartReEncodeToH264(fileURL, originalInfo: videoInfo)
                                    await MainActor.run {
                                        self.downloadedVideoURL = reEncodedURL
                                    }
                                    continuation.resume(returning: reEncodedURL)
                                }
                            } catch {
                                print("❌ Video verification failed: \(error)")
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        print("❌ Downloaded file not found")
                        self.listDirectoryContents(self.tempDirectory)
                        continuation.resume(throwing: YouTubeError.fileNotFound)
                    }
                } else {
                    print("❌ Download failed with exit code: \(task.terminationStatus)")
                    print("📄 Full errors: \(allErrors)")
                    continuation.resume(throwing: YouTubeError.downloadFailed)
                }
                
            } catch {
                print("❌ Failed to start yt-dlp process: \(error)")
                DispatchQueue.main.async {
                    self.isDownloading = false
                }
                continuation.resume(throwing: error)
            }
        }
    }

    // Smart re-encoding that preserves resolution and fixes duration issues
    private func smartReEncodeToH264(_ inputURL: URL, originalInfo: VideoProperties) async throws -> URL {
        let outputURL = tempDirectory.appendingPathComponent("h264_\(UUID().uuidString).mp4")
        
        print("🔄 Smart Re-encoding VP9 → H.264:")
        print("   📁 Input: \(inputURL.path)")
        print("   📁 Output: \(outputURL.path)")
        print("   📐 Resolution: \(Int(originalInfo.resolution.width))x\(Int(originalInfo.resolution.height))")
        print("   ⏱️ Duration: \(originalInfo.duration)s")
        
        // Check if ffmpeg exists
        let ffmpegPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        guard let ffmpegPath = ffmpegPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("❌ FFmpeg not found - cannot re-encode VP9 to H.264")
            throw YouTubeError.ffmpegNotFound
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ffmpegPath)
            
            // Smart encoding arguments to preserve quality and fix duration
            task.arguments = [
                "-i", inputURL.path,
                
                // DURATION FIX - trim to actual video duration if needed
                "-t", String(originalInfo.duration),
                
                // VIDEO: Preserve original resolution and quality
                "-c:v", "libx264",
                "-preset", "medium",            // Good balance
                "-crf", "18",                   // High quality (preserve original)
                "-profile:v", "high",           // H.264 High Profile
                "-level:v", "5.1",              // Support for 4K
                "-pix_fmt", "yuv420p",          // Compatibility
                
                // RESOLUTION: Preserve original (don't scale)
                "-vf", "scale=\(Int(originalInfo.resolution.width)):\(Int(originalInfo.resolution.height))",
                
                // AUDIO: Handle gracefully (if present)
                "-c:a", "aac",
                "-b:a", "128k",
                
                // OPTIMIZATION
                "-movflags", "+faststart",
                "-avoid_negative_ts", "make_zero",
                
                // OVERWRITE
                "-y",
                
                outputURL.path
            ]
            
            print("🚀 Smart re-encoding command:")
            print("   \(ffmpegPath) \(task.arguments!.joined(separator: " "))")
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                print("🏁 Smart re-encoding finished with status: \(task.terminationStatus)")
                
                if task.terminationStatus == 0 {
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
                            if let fileSize = attributes[.size] as? Int64, fileSize > 1000 {
                                print("✅ Smart re-encoding successful!")
                                print("   📁 Output: \(outputURL.path)")
                                print("   📏 Size: \(fileSize) bytes")
                                
                                // Verify the result
                                Task {
                                    do {
                                        let newVideoInfo = try await self.getVideoProperties(at: outputURL)
                                        print("🎬 Re-encoded video verification:")
                                        print("   📐 Resolution: \(Int(newVideoInfo.resolution.width))x\(Int(newVideoInfo.resolution.height))")
                                        print("   🧬 Codec: \(newVideoInfo.codec)")
                                        print("   ⏱️ Duration: \(newVideoInfo.duration)s")
                                        print("   ▶️ Playable: \(newVideoInfo.isPlayable)")
                                        
                                        // Verify resolution is preserved
                                        let resolutionPreserved = abs(newVideoInfo.resolution.width - originalInfo.resolution.width) < 10 &&
                                                                abs(newVideoInfo.resolution.height - originalInfo.resolution.height) < 10
                                        
                                        if self.isCodecCompatible(newVideoInfo.codec) && resolutionPreserved {
                                            print("✅ SUCCESS: Re-encoded video is perfect!")
                                            print("   🎯 Resolution preserved: \(resolutionPreserved)")
                                            
                                            // Clean up original file
                                            try? FileManager.default.removeItem(at: inputURL)
                                            
                                            continuation.resume(returning: outputURL)
                                        } else {
                                            print("❌ Re-encoding verification failed:")
                                            print("   Codec compatible: \(self.isCodecCompatible(newVideoInfo.codec))")
                                            print("   Resolution preserved: \(resolutionPreserved)")
                                            continuation.resume(throwing: YouTubeError.processingFailed)
                                        }
                                    } catch {
                                        print("❌ Failed to verify re-encoded video: \(error)")
                                        continuation.resume(throwing: error)
                                    }
                                }
                                return
                            } else {
                                print("❌ Re-encoded file is empty or too small")
                            }
                        } catch {
                            print("❌ Error checking re-encoded file: \(error)")
                        }
                    } else {
                        print("❌ Re-encoded file was not created")
                    }
                }
                
                // Log error for debugging
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? ""
                print("❌ Smart re-encoding failed:")
                print("   Exit code: \(task.terminationStatus)")
                print("   Error: \(errorString)")
                
                continuation.resume(throwing: YouTubeError.processingFailed)
                
            } catch {
                print("❌ Failed to start smart re-encoding: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }

    // Check if codec is compatible with AVPlayer on macOS
    private func isCodecCompatible(_ codec: String) -> Bool {
        let compatibleCodecs = [
            "avc1",     // H.264 (preferred)
            "h264",     // H.264 alternative name
            "mp4v",     // MPEG-4 Part 2
            "hvc1",     // H.265/HEVC (supported on newer macOS)
            "hev1"      // H.265/HEVC alternative
        ]
        
        let codecLower = codec.lowercased()
        let isCompatible = compatibleCodecs.contains { compatibleCodec in
            codecLower.contains(compatibleCodec.lowercased())
        }
        
        print("🔍 Codec compatibility check:")
        print("   📹 Found codec: '\(codec)'")
        print("   ✅ Compatible codecs: \(compatibleCodecs)")
        print("   🎯 Result: \(isCompatible ? "✅ COMPATIBLE" : "❌ INCOMPATIBLE")")
        
        return isCompatible
    }

    // Enhanced force re-encode with progress tracking
    private func forceReEncodeToH264(_ inputURL: URL) async throws -> URL {
        let outputURL = tempDirectory.appendingPathComponent("h264_\(UUID().uuidString).mp4")
        
        print("🔄 FORCE Re-encoding VP9 → H.264:")
        print("   📁 Input: \(inputURL.path)")
        print("   📁 Output: \(outputURL.path)")
        print("   🎯 Target: H.264 (avc1) codec for AVPlayer compatibility")
        
        // Check if ffmpeg exists
        let ffmpegPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        guard let ffmpegPath = ffmpegPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("❌ FFmpeg not found - cannot re-encode VP9 to H.264")
            print("💡 Install FFmpeg: brew install ffmpeg")
            throw YouTubeError.ffmpegNotFound
        }
        
        print("✅ Using FFmpeg: \(ffmpegPath)")
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ffmpegPath)
            
            // Optimized H.264 encoding for 4K preservation
            task.arguments = [
                "-i", inputURL.path,
                
                // VIDEO: High-quality H.264 encoding
                "-c:v", "libx264",              // H.264 encoder
                "-preset", "slow",              // Better compression for 4K
                "-crf", "18",                   // Near-lossless quality (lower = better)
                "-profile:v", "high",           // H.264 High Profile for 4K
                "-level:v", "5.1",              // H.264 Level 5.1 for 4K support
                "-pix_fmt", "yuv420p",          // Compatible pixel format
                
                // AUDIO: High-quality AAC (if present)
                "-c:a", "aac",
                "-b:a", "192k",
                
                // OPTIMIZATION
                "-movflags", "+faststart",      // Fast preview loading
                "-avoid_negative_ts", "make_zero",
                
                // OVERWRITE
                "-y",
                
                outputURL.path
            ]
            
            print("🚀 Re-encoding command:")
            print("   \(ffmpegPath) \(task.arguments!.joined(separator: " "))")
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                print("🏁 Re-encoding finished with status: \(task.terminationStatus)")
                
                if task.terminationStatus == 0 {
                    // Verify output file exists and has content
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
                            if let fileSize = attributes[.size] as? Int64, fileSize > 1000 {
                                print("✅ Re-encoding successful!")
                                print("   📁 Output: \(outputURL.path)")
                                print("   📏 Size: \(fileSize) bytes")
                                
                                // Verify the new codec
                                Task {
                                    do {
                                        let newVideoInfo = try await self.getVideoProperties(at: outputURL)
                                        print("🎬 Re-encoded video properties:")
                                        print("   📐 Resolution: \(Int(newVideoInfo.resolution.width))x\(Int(newVideoInfo.resolution.height))")
                                        print("   🧬 Codec: \(newVideoInfo.codec)")
                                        print("   ⏱️ Duration: \(newVideoInfo.duration)s")
                                        print("   ▶️ Playable: \(newVideoInfo.isPlayable)")
                                        
                                        if self.isCodecCompatible(newVideoInfo.codec) {
                                            print("✅ SUCCESS: Re-encoded video has compatible codec!")
                                            
                                            // Clean up original VP9 file
                                            try? FileManager.default.removeItem(at: inputURL)
                                            print("🗑️ Cleaned up original VP9 file")
                                            
                                            continuation.resume(returning: outputURL)
                                        } else {
                                            print("❌ FAILED: Re-encoded video still has incompatible codec")
                                            continuation.resume(throwing: YouTubeError.processingFailed)
                                        }
                                    } catch {
                                        print("❌ Failed to verify re-encoded video: \(error)")
                                        continuation.resume(throwing: error)
                                    }
                                }
                                return
                            } else {
                                print("❌ Re-encoded file is empty or too small")
                            }
                        } catch {
                            print("❌ Error checking re-encoded file: \(error)")
                        }
                    } else {
                        print("❌ Re-encoded file was not created")
                    }
                }
                
                // Log error output for debugging
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? ""
                print("❌ Re-encoding failed:")
                print("   Exit code: \(task.terminationStatus)")
                print("   Error output: \(errorString)")
                
                continuation.resume(throwing: YouTubeError.processingFailed)
                
            } catch {
                print("❌ Failed to start re-encoding process: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func getVideoProperties(at url: URL) async throws -> VideoProperties {
        let asset = AVAsset(url: url)
        
        do {
            let duration = try await asset.load(.duration)
            let tracks = try await asset.load(.tracks)
            
            let videoDuration = CMTimeGetSeconds(duration)
            let videoTracks = tracks.filter { $0.mediaType == .video }
            let audioTracks = tracks.filter { $0.mediaType == .audio }
            
            var resolution = CGSize.zero
            var codec = "Unknown"
            
            if let videoTrack = videoTracks.first {
                // Get track size (natural size)
                let naturalSize = try await videoTrack.load(.naturalSize)
                resolution = naturalSize
                
                // Get codec info
                let formatDescriptions = videoTrack.formatDescriptions
                for description in formatDescriptions {
                    let formatDescription = description as! CMVideoFormatDescription
                    let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                    codec = fourCharCodeToString(codecType)
                    break
                }
            }
            
            print("🎬 Video analysis:")
            print("   📐 Resolution: \(Int(resolution.width))x\(Int(resolution.height))")
            print("   ⏱️ Duration: \(videoDuration)s")
            print("   🎥 Video tracks: \(videoTracks.count)")
            print("   🔊 Audio tracks: \(audioTracks.count)")
            print("   🧬 Codec: \(codec)")
            
            return VideoProperties(
                duration: videoDuration,
                resolution: resolution,
                videoTracks: videoTracks.count,
                audioTracks: audioTracks.count,
                codec: codec,
                isPlayable: videoDuration > 0 && !videoTracks.isEmpty
            )
            
        } catch {
            print("❌ Failed to analyze video: \(error)")
            throw error
        }
    }

    // Improved file selection logic
    private func findBestDownloadedFile(baseFilename: String, inDirectory directory: URL) -> URL? {
        print("🔍 Searching for files with base: \(baseFilename)")
        print("📁 In directory: \(directory.path)")
        
        do {
            let allFiles = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            print("📄 All files in directory: \(allFiles)")
            
            // Filter files that match our base filename
            let matchingFiles = allFiles.filter { filename in
                return filename.hasPrefix(baseFilename)
            }
            
            print("🎯 Matching files: \(matchingFiles)")
            
            if matchingFiles.isEmpty {
                print("❌ No matching files found")
                return nil
            }
            
            // Priority order for file selection:
            // 1. Single .mp4 file without format codes (merged file)
            // 2. .mp4 files with video format codes
            // 3. Any .mp4 file
            // 4. Other video formats (.mov, .mkv, etc.)
            // 5. Avoid audio-only files (.webm, .m4a, etc.)
            
            var bestFile: String?
            var bestPriority = Int.max
            
            for filename in matchingFiles {
                let priority = getFilePriority(filename)
                print("📊 File: \(filename), Priority: \(priority)")
                
                if priority < bestPriority {
                    bestPriority = priority
                    bestFile = filename
                }
            }
            
            if let selectedFile = bestFile {
                let fileURL = directory.appendingPathComponent(selectedFile)
                
                // Check file size to ensure it's not empty
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        print("✅ Selected file: \(fileURL.path)")
                        print("📏 File size: \(fileSize) bytes")
                        
                        if fileSize > 1000 { // At least 1KB
                            return fileURL
                        } else {
                            print("⚠️ File is too small, might be corrupted")
                        }
                    }
                } catch {
                    print("❌ Error checking file size: \(error)")
                }
            }
            
            print("❌ No suitable file found")
            return nil
            
        } catch {
            print("❌ Error listing directory contents: \(error)")
            return nil
        }
    }

    // File priority system for better selection
    private func getFilePriority(_ filename: String) -> Int {
        let lowercaseFilename = filename.lowercased()
        
        // Audio-only formats - lowest priority (avoid these)
        if lowercaseFilename.contains(".webm") && (lowercaseFilename.contains("f251") || lowercaseFilename.contains("audio")) {
            return 1000 // Very low priority for audio files
        }
        
        if lowercaseFilename.hasSuffix(".m4a") || lowercaseFilename.hasSuffix(".opus") {
            return 999 // Audio formats
        }
        
        // Merged video files - highest priority
        if lowercaseFilename.hasSuffix(".mp4") && !lowercaseFilename.contains(".f") {
            return 1 // Best: merged MP4 without format codes
        }
        
        // MP4 video files with format codes
        if lowercaseFilename.hasSuffix(".mp4") {
            // Check for video format codes (typically start with higher numbers)
            if lowercaseFilename.contains("f6") || lowercaseFilename.contains("f5") ||
               lowercaseFilename.contains("f4") || lowercaseFilename.contains("f3") {
                return 2 // Good: MP4 video streams
            }
            return 3 // Regular MP4 files
        }
        
        // Other video formats
        if lowercaseFilename.hasSuffix(".mov") || lowercaseFilename.hasSuffix(".mkv") {
            return 10
        }
        
        // WebM video files (might work)
        if lowercaseFilename.hasSuffix(".webm") {
            return 20
        }
        
        // Unknown formats
        return 50
    }

    // Improved video verification
    private func verifyVideoFile(at url: URL) async throws -> Bool {
        print("🔍 Verifying video file: \(url.path)")
        
        let asset = AVAsset(url: url)
        
        do {
            // Load basic properties
            let duration = try await asset.load(.duration)
            let tracks = try await asset.load(.tracks)
            
            let videoDuration = CMTimeGetSeconds(duration)
            let videoTracks = tracks.filter { $0.mediaType == .video }
            
            print("⏱️ Video duration: \(videoDuration) seconds")
            print("🎬 Video tracks found: \(videoTracks.count)")
            
            // Basic validation
            if videoDuration > 0 && !videoTracks.isEmpty {
                // Check codec compatibility
                if let videoTrack = videoTracks.first {
                    let formatDescriptions = videoTrack.formatDescriptions
                    for description in formatDescriptions {
                        let formatDescription = description as! CMVideoFormatDescription
                        let codec = CMFormatDescriptionGetMediaSubType(formatDescription)
                        let codecString = fourCharCodeToString(codec)
                        print("🎬 Video codec: \(codecString)")
                    }
                }
                
                print("✅ Video file verification passed")
                return true
            } else {
                print("❌ Video file validation failed: duration=\(videoDuration), tracks=\(videoTracks.count)")
                return false
            }
            
        } catch {
            print("❌ Video verification error: \(error)")
            return false
        }
    }

    // Re-encoding function for incompatible files
    private func reEncodeToH264(_ inputURL: URL) async throws -> URL {
        let outputURL = tempDirectory.appendingPathComponent("h264_\(UUID().uuidString).mp4")
        
        print("🔄 Re-encoding to H.264:")
        print("   📁 Input: \(inputURL.path)")
        print("   📁 Output: \(outputURL.path)")
        
        // Check if ffmpeg exists
        let ffmpegPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        guard let ffmpegPath = ffmpegPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("❌ FFmpeg not found - cannot re-encode")
            throw YouTubeError.ffmpegNotFound
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ffmpegPath)
            task.arguments = [
                "-i", inputURL.path,
                "-c:v", "libx264",           // Force H.264 video codec
                "-preset", "fast",          // Fast encoding
                "-crf", "23",               // Good quality
                "-c:a", "aac",              // AAC audio codec
                "-movflags", "+faststart",  // Optimize for streaming
                "-y",                       // Overwrite output
                outputURL.path
            ]
            
            print("🚀 Re-encoding: \(ffmpegPath) \(task.arguments!.joined(separator: " "))")
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                print("🏁 Re-encoding finished with status: \(task.terminationStatus)")
                
                if task.terminationStatus == 0 {
                    // Verify output file
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
                        if let fileSize = attributes[.size] as? Int64, fileSize > 1000 {
                            print("✅ Re-encoding successful: \(outputURL.path) (\(fileSize) bytes)")
                            
                            // Clean up original file
                            try? FileManager.default.removeItem(at: inputURL)
                            
                            continuation.resume(returning: outputURL)
                            return
                        }
                    }
                }
                
                print("❌ Re-encoding failed")
                continuation.resume(throwing: YouTubeError.processingFailed)
                
            } catch {
                print("❌ Failed to start re-encoding: \(error)")
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
        
        // Try stream copy first (faster), then fallback to re-encoding
        let success = await tryStreamCopy(ffmpegPath: ffmpegPath, inputURL: inputURL, startTime: startTime, duration: duration, outputPath: outputPath)
        
        if !success {
            print("⚠️ Stream copy failed, trying re-encoding...")
            try await tryReEncoding(ffmpegPath: ffmpegPath, inputURL: inputURL, startTime: startTime, duration: duration, outputPath: outputPath)
        }
    }
    
    private func tryStreamCopy(ffmpegPath: String, inputURL: URL, startTime: Double, duration: Double, outputPath: URL) async -> Bool {
        return await withCheckedContinuation { continuation in
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
            
            print("🚀 Trying stream copy: \(ffmpegPath) \(task.arguments!.joined(separator: " "))")
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                print("🏁 Stream copy finished with status: \(task.terminationStatus)")
                
                if task.terminationStatus == 0 {
                    // Verify output file was created and has content
                    if FileManager.default.fileExists(atPath: outputPath.path) {
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: outputPath.path)
                            if let fileSize = attributes[.size] as? Int64, fileSize > 0 {
                                print("✅ Stream copy successful: \(outputPath.path) (\(fileSize) bytes)")
                                continuation.resume(returning: true)
                                return
                            }
                        } catch {
                            print("❌ Error checking output file: \(error)")
                        }
                    }
                }
                
                // Log error output for debugging
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? ""
                print("⚠️ Stream copy failed (exit \(task.terminationStatus)): \(errorString)")
                
                continuation.resume(returning: false)
                
            } catch {
                print("❌ Failed to start stream copy process: \(error)")
                continuation.resume(returning: false)
            }
        }
    }
    
    private func tryReEncoding(ffmpegPath: String, inputURL: URL, startTime: Double, duration: Double, outputPath: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ffmpegPath)
            
            // Re-encoding with H.264 - compatible with macOS wallpapers
            task.arguments = [
                "-i", inputURL.path,
                "-ss", String(startTime),
                "-t", String(duration),
                "-c:v", "libx264",              // H.264 video codec
                "-preset", "medium",            // Balans mezi rychlostí a kvalitou
                "-crf", "23",                   // Kvalita (18-28, nižší = lepší)
                "-pix_fmt", "yuv420p",          // Pixel format kompatibilní s QuickTime
                "-movflags", "+faststart",      // Optimalizace pro streaming
                "-an",                          // Žádný zvuk
                "-avoid_negative_ts", "make_zero",
                "-y",
                outputPath.path
            ]
            
            print("🚀 Re-encoding: \(ffmpegPath) \(task.arguments!.joined(separator: " "))")
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            // Monitor progress
            var allOutput = ""
            var allErrors = ""
            
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    allErrors += output
                    print("🔍 FFmpeg: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
            
            do {
                try task.run()
                
                task.terminationHandler = { _ in
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    DispatchQueue.main.async {
                        print("🏁 Re-encoding finished with status: \(task.terminationStatus)")
                        
                        if task.terminationStatus == 0 {
                            // Verify output file was created and has content
                            if FileManager.default.fileExists(atPath: outputPath.path) {
                                do {
                                    let attributes = try FileManager.default.attributesOfItem(atPath: outputPath.path)
                                    if let fileSize = attributes[.size] as? Int64, fileSize > 0 {
                                        print("✅ Re-encoding successful: \(outputPath.path) (\(fileSize) bytes)")
                                        continuation.resume()
                                        return
                                    } else {
                                        print("❌ Re-encoded file is empty")
                                    }
                                } catch {
                                    print("❌ Error checking re-encoded file: \(error)")
                                }
                            } else {
                                print("❌ Re-encoded file was not created")
                            }
                            continuation.resume(throwing: YouTubeError.processingFailed)
                        } else {
                            print("❌ Re-encoding failed with exit code: \(task.terminationStatus)")
                            print("📄 Full errors: \(allErrors)")
                            continuation.resume(throwing: YouTubeError.processingFailed)
                        }
                    }
                }
                
            } catch {
                print("❌ Failed to start re-encoding process: \(error)")
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


extension YouTubeImportManager {
    
    func diagnoseVideoFile(_ url: URL) async -> VideoDiagnostics {
        var diagnostics = VideoDiagnostics()
        
        do {
            // Basic file info
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            diagnostics.fileSize = attributes[.size] as? Int64 ?? 0
            diagnostics.fileExists = true
            
            // AVAsset analysis
            let asset = AVAsset(url: url)
            
            // Load basic properties - using older syntax for compatibility
            let duration = try await asset.load(.duration)
            let isPlayable = try await asset.load(.isPlayable)
            let tracks = try await asset.load(.tracks)
            
            diagnostics.duration = CMTimeGetSeconds(duration)
            diagnostics.isPlayable = isPlayable
            diagnostics.trackCount = tracks.count
            
            // Analyze video tracks - using synchronous properties
            let videoTracks = tracks.compactMap { track -> AVAssetTrack? in
                // Use synchronous mediaType property
                return track.mediaType == .video ? track : nil
            }
            
            diagnostics.videoTrackCount = videoTracks.count
            
            if let videoTrack = videoTracks.first {
                // Use synchronous properties for track info
                let formatDescriptions = videoTrack.formatDescriptions
                for description in formatDescriptions {
                    let formatDescription = description as! CMVideoFormatDescription
                    let codec = CMFormatDescriptionGetMediaSubType(formatDescription)
                    diagnostics.videoCodec = fourCharCodeToString(codec)
                    break
                }
                
                let naturalSize = videoTrack.naturalSize
                diagnostics.resolution = "\(Int(naturalSize.width))x\(Int(naturalSize.height))"
            }
            
            // Analyze audio tracks - using synchronous properties
            let audioTracks = tracks.compactMap { track -> AVAssetTrack? in
                return track.mediaType == .audio ? track : nil
            }
            
            diagnostics.audioTrackCount = audioTracks.count
            
        } catch {
            diagnostics.error = error.localizedDescription
        }
        
        return diagnostics
    }
    
    private func fourCharCodeToString(_ code: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "Unknown"
    }
}

// Also fix the verifyVideoFile function
private func verifyVideoFile(_ url: URL) async -> Bool {
    do {
        // Basic file checks
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ File doesn't exist: \(url.path)")
            return false
        }
        
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSizeValue = attributes[.size] as? Int64, fileSizeValue > 1000 else {
            let size = attributes[.size] as? Int64 ?? 0
            print("❌ File too small: \(size) bytes")
            return false
        }
        
        print("📏 File size: \(fileSizeValue) bytes")
        
        // Try to load with AVAsset
        let asset = AVAsset(url: url)
        
        let isPlayable = try await asset.load(.isPlayable)
        let tracks = try await asset.load(.tracks)
        
        print("✅ Basic verification passed:")
        print("   📏 Size: \(fileSizeValue) bytes (\(String(format: "%.2f", Double(fileSizeValue) / 1024 / 1024)) MB)")
        print("   📄 Extension: \(url.pathExtension)")
        print("   🎬 Is playable: \(isPlayable)")
        print("   📹 Track count: \(tracks.count)")
        
        // Check for video tracks using synchronous properties
        let videoTracks = tracks.filter { track in
            track.mediaType == .video
        }
        
        if videoTracks.isEmpty {
            print("❌ No video tracks found")
            return false
        }
        
        print("✅ Video file verification passed")
        return true
        
    } catch {
        print("❌ Video verification failed: \(error)")
        return false
    }
}

struct VideoDiagnostics {
    var fileExists = false
    var fileSize: Int64 = 0
    var duration: Double = 0
    var isPlayable = false
    var trackCount = 0
    var videoTrackCount = 0
    var audioTrackCount = 0
    var videoCodec = "Unknown"
    var resolution = "Unknown"
    var error: String?
    
    var summary: String {
        var lines: [String] = []
        lines.append("File exists: \(fileExists)")
        lines.append("File size: \(ByteCountFormatter().string(fromByteCount: fileSize))")
        lines.append("Duration: \(String(format: "%.1f", duration))s")
        lines.append("Is playable: \(isPlayable)")
        lines.append("Video tracks: \(videoTrackCount)")
        lines.append("Audio tracks: \(audioTrackCount)")
        lines.append("Video codec: \(videoCodec)")
        lines.append("Resolution: \(resolution)")
        if let error = error {
            lines.append("Error: \(error)")
        }
        return lines.joined(separator: "\n")
    }
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
