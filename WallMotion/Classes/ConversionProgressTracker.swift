//
//  ConversionProgressTracker.swift
//  WallMotion - Enhanced conversion progress tracking
//

import Foundation
import SwiftUI

// MARK: - Enhanced Progress Info Structure
struct EnhancedProgressInfo {
    let state: ConversionState
    let progress: Double  // 0.0 - 1.0
    let currentTime: Double
    let totalTime: Double
    let estimatedTimeRemaining: Double?
    let conversionSpeed: Double? // multiplier (1x, 2x, etc.)
    let message: String
    
    static let initial = EnhancedProgressInfo(
        state: .preparing,
        progress: 0.0,
        currentTime: 0.0,
        totalTime: 0.0,
        estimatedTimeRemaining: nil,
        conversionSpeed: nil,
        message: "Preparing conversion..."
    )
}

enum ConversionState {
    case preparing
    case analyzing
    case converting
    case finalizing
    case completed
    case failed
}

// MARK: - Conversion Progress Tracker
@MainActor
class ConversionProgressTracker: ObservableObject {
    @Published var progressInfo = EnhancedProgressInfo.initial
    
    private var startTime: Date?
    private var lastUpdateTime: Date?
    private var lastProcessedTime: Double = 0.0
    private var speedSamples: [Double] = []
    private let maxSpeedSamples = 10
    
    func reset() {
        progressInfo = EnhancedProgressInfo.initial
        startTime = nil
        lastUpdateTime = nil
        lastProcessedTime = 0.0
        speedSamples.removeAll()
    }
    
    func updateProgress(
        state: ConversionState,
        currentTime: Double,
        totalTime: Double,
        rawMessage: String? = nil
    ) {
        let now = Date()
        
        // Initialize start time
        if startTime == nil {
            startTime = now
        }
        
        // Calculate progress
        let progress = totalTime > 0 ? min(currentTime / totalTime, 1.0) : 0.0
        
        // Calculate conversion speed and ETA
        var estimatedTimeRemaining: Double?
        var conversionSpeed: Double?
        
        if let lastUpdate = lastUpdateTime, state == .converting {
            let timeDelta = now.timeIntervalSince(lastUpdate)
            let processedDelta = currentTime - lastProcessedTime
            
            if timeDelta > 0 && processedDelta > 0 {
                let currentSpeed = processedDelta / timeDelta
                speedSamples.append(currentSpeed)
                
                // Keep only recent samples
                if speedSamples.count > maxSpeedSamples {
                    speedSamples.removeFirst()
                }
                
                // Calculate average speed
                let avgSpeed = speedSamples.reduce(0, +) / Double(speedSamples.count)
                conversionSpeed = avgSpeed
                
                // Calculate ETA
                let remainingTime = totalTime - currentTime
                if avgSpeed > 0 {
                    estimatedTimeRemaining = remainingTime / avgSpeed
                }
            }
        }
        
        // Generate user-friendly message
        let message = generateMessage(
            state: state,
            progress: progress,
            estimatedTimeRemaining: estimatedTimeRemaining,
            conversionSpeed: conversionSpeed,
            rawMessage: rawMessage
        )
        
        // Update progress info
        progressInfo = EnhancedProgressInfo(
            state: state,
            progress: progress,
            currentTime: currentTime,
            totalTime: totalTime,
            estimatedTimeRemaining: estimatedTimeRemaining,
            conversionSpeed: conversionSpeed,
            message: message
        )
        
        // Update tracking variables
        lastUpdateTime = now
        lastProcessedTime = currentTime
        
        print("🎬 Conversion progress: \(Int(progress * 100))% - \(message)")
    }
    
    private func generateMessage(
        state: ConversionState,
        progress: Double,
        estimatedTimeRemaining: Double?,
        conversionSpeed: Double?,
        rawMessage: String?
    ) -> String {
        switch state {
        case .preparing:
            return "Preparing video conversion..."
            
        case .analyzing:
            return "Analyzing video properties..."
            
        case .converting:
            var message = "Converting to H.264: \(Int(progress * 100))%"
            
            // Add speed info if available
            if let speed = conversionSpeed, speed > 0 {
                let speedMultiplier = speed
                if speedMultiplier >= 1.0 {
                    message += " (\(String(format: "%.1f", speedMultiplier))x speed)"
                } else {
                    message += " (\(String(format: "%.2f", speedMultiplier))x speed)"
                }
            }
            
            // Add ETA if available
            if let eta = estimatedTimeRemaining, eta > 0 && eta < 3600 { // Max 1 hour
                let etaFormatted = formatTimeRemaining(eta)
                message += " • \(etaFormatted) remaining"
            }
            
            return message
            
        case .finalizing:
            return "Finalizing conversion..."
            
        case .completed:
            return "Conversion completed successfully!"
            
        case .failed:
            return rawMessage ?? "Conversion failed"
        }
    }
    
    private func formatTimeRemaining(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        
        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        } else if totalSeconds < 3600 {
            let minutes = totalSeconds / 60
            let remainingSeconds = totalSeconds % 60
            if remainingSeconds == 0 {
                return "\(minutes)m"
            } else {
                return "\(minutes)m \(remainingSeconds)s"
            }
        } else {
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
}

// MARK: - Enhanced FFmpeg Progress Parser
struct EnhancedFFmpegProgressParser {
    
    static func parseProgress(
        from output: String,
        totalDuration: Double,
        tracker: ConversionProgressTracker
    ) async {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // Parse FFmpeg progress line
            if let progressData = parseFFmpegProgressLine(line) {
                await tracker.updateProgress(
                    state: .converting,
                    currentTime: progressData.currentTime,
                    totalTime: totalDuration
                )
                return
            }
            
            // Parse other FFmpeg status messages
            if line.contains("Stream mapping:") {
                await tracker.updateProgress(
                    state: .analyzing,
                    currentTime: 0,
                    totalTime: totalDuration,
                    rawMessage: "Analyzing video streams..."
                )
            } else if line.contains("Press [q] to stop") {
                await tracker.updateProgress(
                    state: .converting,
                    currentTime: 0,
                    totalTime: totalDuration,
                    rawMessage: "Starting conversion..."
                )
            }
        }
    }
    
    private static func parseFFmpegProgressLine(_ line: String) -> (currentTime: Double, fps: Double?, speed: Double?)? {
        // FFmpeg progress line typically looks like:
        // frame= 1234 fps= 25 q=28.0 size=   12345kB time=00:01:23.45 bitrate=1234.5kbits/s speed=1.2x
        
        var currentTime: Double?
        var fps: Double?
        var speed: Double?
        
        // Parse time=XX:XX:XX.XX
        if let timeMatch = line.range(of: #"time=(\d{2}):(\d{2}):(\d{2})\.(\d{2})"#, options: .regularExpression) {
            let timeString = String(line[timeMatch])
            if let parsedTime = parseTimeString(timeString.replacingOccurrences(of: "time=", with: "")) {
                currentTime = parsedTime
            }
        }
        
        // Parse fps=XX.X
        if let fpsMatch = line.range(of: #"fps=\s*(\d+\.?\d*)"#, options: .regularExpression) {
            let fpsString = String(line[fpsMatch])
            if let fpsValue = Double(fpsString.replacingOccurrences(of: "fps=", with: "").trimmingCharacters(in: .whitespaces)) {
                fps = fpsValue
            }
        }
        
        // Parse speed=X.Xx
        if let speedMatch = line.range(of: #"speed=\s*(\d+\.?\d*)x"#, options: .regularExpression) {
            let speedString = String(line[speedMatch])
            if let speedValue = Double(speedString.replacingOccurrences(of: "speed=", with: "").replacingOccurrences(of: "x", with: "").trimmingCharacters(in: .whitespaces)) {
                speed = speedValue
            }
        }
        
        if let time = currentTime {
            return (currentTime: time, fps: fps, speed: speed)
        }
        
        return nil
    }
    
    private static func parseTimeString(_ timeString: String) -> Double? {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 3 else { return nil }
        
        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return nil
        }
        
        return hours * 3600 + minutes * 60 + seconds
    }
}

// MARK: - Enhanced YouTube Processing Section UI
struct EnhancedYouTubeProcessingSection: View {
    @ObservedObject var progressTracker: ConversionProgressTracker
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                progressIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(progressTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(progressTracker.progressInfo.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // Progress visualization
            progressVisualization
            
            // Detailed info
            if progressTracker.progressInfo.state == .converting {
                detailedConversionInfo
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(progressColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var progressIcon: some View {
        Group {
            switch progressTracker.progressInfo.state {
            case .preparing, .analyzing:
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                
            case .converting:
                ZStack {
                    Circle()
                        .stroke(.blue.opacity(0.2), lineWidth: 3)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .trim(from: 0, to: progressTracker.progressInfo.progress)
                        .stroke(.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progressTracker.progressInfo.progress)
                }
                
            case .finalizing:
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
            }
        }
    }
    
    private var progressVisualization: some View {
        VStack(spacing: 8) {
            // Progress bar
            ProgressView(value: progressTracker.progressInfo.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .frame(height: 6)
            
            // Progress percentage and time info
            HStack {
                Text("\(Int(progressTracker.progressInfo.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(progressColor)
                
                Spacer()
                
                if let eta = progressTracker.progressInfo.estimatedTimeRemaining,
                   progressTracker.progressInfo.state == .converting {
                    Text("~\(formatTimeRemaining(eta)) left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var detailedConversionInfo: some View {
        HStack(spacing: 16) {
            // Current time / Total time
            VStack(alignment: .leading, spacing: 2) {
                Text("Progress")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("\(formatTime(progressTracker.progressInfo.currentTime)) / \(formatTime(progressTracker.progressInfo.totalTime))")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            // Conversion speed
            if let speed = progressTracker.progressInfo.conversionSpeed, speed > 0 {
                VStack(alignment: .center, spacing: 2) {
                    Text("Speed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", speed))x")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(speed >= 1.0 ? .green : .orange)
                }
            }
            
            Spacer()
            
            // ETA
            if let eta = progressTracker.progressInfo.estimatedTimeRemaining {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(formatTimeRemaining(eta))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.top, 4)
    }
    
    private var progressTitle: String {
        switch progressTracker.progressInfo.state {
        case .preparing: return "Preparing Conversion"
        case .analyzing: return "Analyzing Video"
        case .converting: return "Converting Video"
        case .finalizing: return "Finalizing"
        case .completed: return "Conversion Complete"
        case .failed: return "Conversion Failed"
        }
    }
    
    private var progressColor: Color {
        switch progressTracker.progressInfo.state {
        case .preparing, .analyzing: return .blue
        case .converting: return .blue
        case .finalizing: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func formatTimeRemaining(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        
        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        } else if totalSeconds < 3600 {
            let minutes = totalSeconds / 60
            let remainingSeconds = totalSeconds % 60
            if remainingSeconds == 0 {
                return "\(minutes)m"
            } else {
                return "\(minutes)m \(remainingSeconds)s"
            }
        } else {
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
}
