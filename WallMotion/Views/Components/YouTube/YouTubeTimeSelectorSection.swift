//
//  YouTubeTimeSelectorSection.swift
//  WallMotion
//
//  Time selector section with working range slider
//

import SwiftUI

struct YouTubeTimeSelectorSection: View {
    @ObservedObject var importManager: YouTubeImportManager
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("Select Wallpaper Duration")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Drag the handles to set start and end time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                YouTubeTimeRangeDisplay(
                    startTime: importManager.selectedStartTime,
                    endTime: importManager.selectedEndTime
                )
                
                YouTubeRangeSliderView(
                    startValue: $importManager.selectedStartTime,
                    endValue: $importManager.selectedEndTime,
                    bounds: 0...importManager.maxDuration,
                    step: 1
                )
                .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                
                YouTubeTimeMarkers(maxDuration: importManager.maxDuration)
                
                Text("Recommended: 30-60 seconds for best wallpaper performance")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

struct YouTubeTimeRangeDisplay: View {
    let startTime: Double
    let endTime: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start Time")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "play.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text(formatTime(startTime))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("Duration")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(formatTime(endTime - startTime))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("End Time")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(formatTime(endTime))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Image(systemName: "stop.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct YouTubeTimeMarkers: View {
    let maxDuration: Double
    
    var body: some View {
        HStack {
            Text("0:00")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(formatTime(maxDuration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Working Range Slider with Bindings

struct YouTubeRangeSliderView: View {
    @Binding var startValue: Double
    @Binding var endValue: Double
    let bounds: ClosedRange<Double>
    let step: Double
    
    @State private var trackHeight: CGFloat = 4
    @State private var thumbSize: CGFloat = 20
    
    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width - thumbSize
            let range = bounds.upperBound - bounds.lowerBound
            let startOffset = CGFloat((startValue - bounds.lowerBound) / range) * trackWidth
            let endOffset = CGFloat((endValue - bounds.lowerBound) / range) * trackWidth
            
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(.gray.opacity(0.3))
                    .frame(height: trackHeight)
                    .offset(x: thumbSize / 2)
                
                // Active track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(LinearGradient(
                        colors: [.blue, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: max(0, endOffset - startOffset), height: trackHeight)
                    .offset(x: thumbSize / 2 + startOffset)
                
                // Start thumb
                Circle()
                    .fill(.blue)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: startOffset)
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .frame(width: thumbSize, height: thumbSize)
                            .offset(x: startOffset)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = bounds.lowerBound + Double(value.location.x / trackWidth) * range
                                let steppedValue = round(newValue / step) * step
                                let clampedValue = max(bounds.lowerBound, min(endValue - 5, steppedValue))
                                startValue = clampedValue
                            }
                    )
                
                // End thumb
                Circle()
                    .fill(.orange)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: endOffset)
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .frame(width: thumbSize, height: thumbSize)
                            .offset(x: endOffset)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = bounds.lowerBound + Double(value.location.x / trackWidth) * range
                                let steppedValue = round(newValue / step) * step
                                let clampedValue = max(startValue + 5, min(bounds.upperBound, steppedValue))
                                endValue = clampedValue
                            }
                    )
            }
        }
        .frame(height: thumbSize)
    }
}

#Preview {
    YouTubeTimeSelectorSection(
        importManager: YouTubeImportManager()
    )
    .padding()
}
