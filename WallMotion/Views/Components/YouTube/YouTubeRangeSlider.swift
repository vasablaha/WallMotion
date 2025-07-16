//
//  YouTubeRangeSlider.swift
//  WallMotion
//
//  Custom range slider component for YouTube Import
//

import SwiftUI

struct YouTubeRangeSlider: View {
    let startValue: Double
    let endValue: Double
    let bounds: ClosedRange<Double>
    let step: Double
    let onStartChange: (Double) -> Void
    let onEndChange: (Double) -> Void
    
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
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: trackHeight)
                    .offset(x: thumbSize / 2)
                
                // Active track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(LinearGradient(
                        colors: [Color.blue, Color.orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: endOffset - startOffset, height: trackHeight)
                    .offset(x: thumbSize / 2 + startOffset)
                
                // Start thumb
                Circle()
                    .fill(Color.blue)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: startOffset)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: thumbSize, height: thumbSize)
                            .offset(x: startOffset)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = bounds.lowerBound + Double(value.location.x / trackWidth) * range
                                let steppedValue = round(newValue / step) * step
                                let clampedValue = max(bounds.lowerBound, min(endValue - 5, steppedValue))
                                onStartChange(clampedValue)
                            }
                    )
                
                // End thumb
                Circle()
                    .fill(Color.orange)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: endOffset)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: thumbSize, height: thumbSize)
                            .offset(x: endOffset)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = bounds.lowerBound + Double(value.location.x / trackWidth) * range
                                let steppedValue = round(newValue / step) * step
                                let clampedValue = max(startValue + 5, min(bounds.upperBound, steppedValue))
                                onEndChange(clampedValue)
                            }
                    )
            }
        }
        .frame(height: thumbSize)
    }
}

#Preview {
    @State var startValue = 10.0
    @State var endValue = 60.0
    
    return VStack {
        Text("Start: \(Int(startValue))s, End: \(Int(endValue))s")
            .font(.headline)
            .padding()
        
        YouTubeRangeSlider(
            startValue: startValue,
            endValue: endValue,
            bounds: 0...120,
            step: 1,
            onStartChange: { value in
                startValue = value
            },
            onEndChange: { value in
                endValue = value
            }
        )
        .padding()
    }
    .frame(width: 400, height: 200)
}
