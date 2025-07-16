//
//  TutorialView.swift
//  WallMotion
//
//  Tutorial component for first-time setup
//

import SwiftUI

struct TutorialView: View {
    @State private var currentStep = 0
    @Environment(\.colorScheme) private var colorScheme
    let onComplete: (() -> Void)?
    let isInSidebar: Bool
    
    init(onComplete: (() -> Void)? = nil, isInSidebar: Bool = false) {
        self.onComplete = onComplete
        self.isInSidebar = isInSidebar
    }
    
    private let tutorialSteps: [TutorialStep] = [
        TutorialStep(
                   title: "Choose Video Wallpaper",
                   subtitle: "Select 'Sonoma Horizon' wallpaper",
                   content: "In the Wallpaper settings, scroll down to the Dynamic Desktop section and select 'Sonoma Horizon' wallpaper. This specific wallpaper creates the correct video wallpaper structure that WallMotion needs to function properly.",
                   icon: "video.fill",
                   videoPlaceholder: "Screen recording of selecting Sonoma Horizon wallpaper"
               ),
        TutorialStep(
            title: "Open System Settings",
            subtitle: "Navigate to Wallpaper settings",
            content: "Go to Apple menu > System Settings (or System Preferences on older macOS), then click on 'Wallpaper' in the sidebar.",
            icon: "gearshape.fill",
            videoPlaceholder: "Screen recording of opening System Settings"
        ),
        TutorialStep(
            title: "Choose Video Wallpaper",
            subtitle: "Select any video wallpaper from the library",
            content: "In the Wallpaper settings, scroll down and select any video from the Dynamic Desktop section. This creates the initial video wallpaper structure that WallMotion needs.",
            icon: "video.fill",
            videoPlaceholder: "Screen recording of selecting video wallpaper"
        ),
        TutorialStep(
            title: "Wait for Download",
            subtitle: "Let macOS download the wallpaper",
            content: "macOS will download the selected video wallpaper. Wait for this process to complete - you'll see a progress indicator. This usually takes 1-2 minutes.",
            icon: "arrow.down.circle.fill",
            videoPlaceholder: "Screen recording of download process"
        ),
        TutorialStep(
            title: "Enable Background & Screensaver",
            subtitle: "Make sure both options are enabled",
            content: "Ensure that both 'Desktop' and 'Screen Saver' toggles are enabled in the wallpaper settings. This allows the video to play on both your desktop and as a screensaver.",
            icon: "switch.2",
            videoPlaceholder: "Screen recording of enabling toggles"
        ),
        TutorialStep(
            title: "Return to WallMotion",
            subtitle: "Now you can use your custom videos",
            content: "Come back to WallMotion. The app will now detect your video wallpaper and allow you to replace it with your own custom videos or YouTube imports.",
            icon: "checkmark.circle.fill",
            videoPlaceholder: "Screen recording of using WallMotion"
        ),
        TutorialStep(
            title: "Choose Your Video",
            subtitle: "Upload or import your video",
            content: "Click 'Choose Video File' to select a local video file, or use 'Import from YouTube' to download a video from YouTube. WallMotion supports MP4, MOV, and other common formats.",
            icon: "plus.rectangle.on.rectangle",
            videoPlaceholder: "Screen recording of selecting video in WallMotion"
        ),
        TutorialStep(
            title: "Set as Wallpaper",
            subtitle: "Apply your custom wallpaper",
            content: "After selecting your video, click 'Set as Wallpaper'. WallMotion will request administrator permission (one time only) to replace the system wallpaper file. Your custom video will then become your new live wallpaper!",
            icon: "sparkles",
            videoPlaceholder: "Screen recording of setting wallpaper"
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            if !isInSidebar {
                headerSection
            }
            
            contentSection
            
            if !isInSidebar {
                navigationSection
            }
        }
        .background(backgroundGradient)
        .cornerRadius(isInSidebar ? 0 : 20)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                if let onComplete = onComplete {
                    Button(action: onComplete) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Skip Tutorial")
                }
            }
            .padding(.top, 15)
            .padding(.trailing, 20)
            
            VStack(spacing: 15) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 50, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Setup Tutorial")
                    .font(.title)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
            }
        }
        .padding(.horizontal, isInSidebar ? 20 : 40)
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(spacing: 24) {
            // Progress indicator
            progressIndicator
            
            // Current step content
            currentStepContent
            
            // Step navigation (in sidebar)
            if isInSidebar {
                stepNavigationButtons
            }
        }
        .padding(.horizontal, isInSidebar ? 20 : 40)
        .padding(.vertical, 20)
    }
    
    private var progressIndicator: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Step \(currentStep + 1) of \(tutorialSteps.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(Double(currentStep + 1) / Double(tutorialSteps.count) * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: Double(currentStep + 1), total: Double(tutorialSteps.count))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 1.5)
        }
    }
    
    private var currentStepContent: some View {
        let step = tutorialSteps[currentStep]
        
        return VStack(spacing: 20) {
            // Step icon and title
            VStack(spacing: 12) {
                Image(systemName: step.icon)
                    .font(.system(size: isInSidebar ? 30 : 40, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 6) {
                    Text(step.title)
                        .font(isInSidebar ? .headline : .title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(step.subtitle)
                        .font(isInSidebar ? .caption : .subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Video placeholder
            videoPlaceholder(step.videoPlaceholder)
            
            // Step description
            Text(step.content)
                .font(isInSidebar ? .caption : .body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(isInSidebar ? 4 : nil)
                .padding(.horizontal, isInSidebar ? 0 : 20)
        }
        .frame(maxWidth: .infinity)
        .padding(isInSidebar ? 12 : 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func videoPlaceholder(_ description: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: isInSidebar ? 80 : 120)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: isInSidebar ? 20 : 30))
                        .foregroundColor(.blue.opacity(0.7))
                    
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.blue.opacity(0.3), lineWidth: 1)
            )
    }
    
    // MARK: - Navigation Section
    
    private var navigationSection: some View {
        HStack(spacing: 20) {
            // Previous button
            Button(action: previousStep) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .frame(minWidth: 100)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(currentStep == 0)
            
            Spacer()
            
            // Step dots
            HStack(spacing: 8) {
                ForEach(0..<tutorialSteps.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? .blue : .gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentStep ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }
            
            Spacer()
            
            // Next/Complete button
            Button(action: nextStep) {
                HStack {
                    Text(currentStep == tutorialSteps.count - 1 ? "Complete" : "Next")
                    if currentStep < tutorialSteps.count - 1 {
                        Image(systemName: "chevron.right")
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
                .frame(minWidth: 100)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
    }
    
    private var stepNavigationButtons: some View {
        HStack(spacing: 12) {
            Button(action: previousStep) {
                Image(systemName: "chevron.left")
                    .font(.caption)
            }
            .buttonStyle(TertiaryButtonStyle())
            .disabled(currentStep == 0)
            
            // Compact step dots
            HStack(spacing: 4) {
                ForEach(0..<tutorialSteps.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? .blue : .gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            
            Button(action: nextStep) {
                Image(systemName: currentStep == tutorialSteps.count - 1 ? "checkmark" : "chevron.right")
                    .font(.caption)
            }
            .buttonStyle(TertiaryButtonStyle())
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark ?
                [Color.black.opacity(0.8), Color.blue.opacity(0.1)] :
                [Color.white, Color.blue.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Methods
    
    private func nextStep() {
        if currentStep < tutorialSteps.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } else {
            // Tutorial completed
            onComplete?()
        }
    }
    
    private func previousStep() {
        if currentStep > 0 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep -= 1
            }
        }
    }
}

// MARK: - Tutorial Step Model

struct TutorialStep {
    let title: String
    let subtitle: String
    let content: String
    let icon: String
    let videoPlaceholder: String
}

// MARK: - Button Styles

struct TertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(.primary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    TutorialView(onComplete: {
        print("Tutorial completed")
    })
    .frame(width: 600, height: 700)
}

#Preview("Sidebar") {
    TutorialView(isInSidebar: true)
        .frame(width: 300, height: 400)
}
