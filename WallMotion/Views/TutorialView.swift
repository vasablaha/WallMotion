//
//  TutorialView.swift
//  WallMotion
//
//  Tutorial component for first-time setup with fixed layout and images
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
            title: "Open System Settings",
            subtitle: "Navigate to Wallpaper settings",
            content: "Go to Apple menu > System Settings (or System Preferences on older macOS), then click on 'Wallpaper' in the sidebar. This is where you'll set up the initial video wallpaper structure.",
            icon: "gearshape.fill",
            imagePlaceholder: "1tutorial",
            stepType: .setup
        ),
        
        TutorialStep(
            title: "Select 'Sonoma Horizon' Wallpaper",
            subtitle: "Choose this specific dynamic wallpaper",
            content: "In the Wallpaper settings, scroll down to find the 'Dynamic Desktop' section. Select specifically the 'Sonoma Horizon' wallpaper. This creates the correct video wallpaper file structure that WallMotion needs to function properly.",
            icon: "mountain.2.fill",
            imagePlaceholder: "1tutorial",
            stepType: .setup
        ),
        
        TutorialStep(
            title: "Wait for Download",
            subtitle: "Let macOS download the wallpaper files",
            content: "macOS will automatically download the 'Sonoma Horizon' video files to your system. You'll see a progress indicator. This usually takes 1-3 minutes depending on your internet connection. Don't close System Settings yet!",
            icon: "arrow.down.circle.fill",
            imagePlaceholder: "1tutorial",
            stepType: .setup
        ),
        
        TutorialStep(
            title: "Enable All Display Options",
            subtitle: "Configure desktop and screensaver settings",
            content: "Make sure both 'Desktop' and 'Screen Saver' toggles are enabled. Also click 'Set for all Displays' if you have multiple monitors. This ensures the video wallpaper works everywhere.",
            icon: "switch.2",
            imagePlaceholder: "1tutorial",
            stepType: .setup
        ),
        
        TutorialStep(
            title: "Return to WallMotion",
            subtitle: "Setup complete, now customize!",
            content: "Close System Settings and return to WallMotion. The app will now detect your video wallpaper setup. You'll see the current wallpaper status in the sidebar. Now you can replace it with your own custom videos!",
            icon: "checkmark.circle.fill",
            imagePlaceholder: "2tutorial",
            stepType: .setup
        ),
        
        TutorialStep(
            title: "Choose Your Video Method",
            subtitle: "Two ways to add your videos",
            content: "WallMotion offers two convenient ways to get your videos: upload a local video file from your computer, or import directly from YouTube. Both methods support high-quality video processing.",
            icon: "arrow.triangle.branch",
            imagePlaceholder: "2tutorial",
            stepType: .usage
        ),
        
        TutorialStep(
            title: "Method 1: Upload Local Video",
            subtitle: "Use videos from your computer",
            content: "Click 'Choose Video File' to select a video from your Mac. Supported formats: MP4, MOV, AVI, MKV. Best results with 1080p or 4K videos. The video will be automatically optimized for wallpaper use.",
            icon: "folder.badge.plus",
            imagePlaceholder: "2tutorial",
            stepType: .usage
        ),
        
        TutorialStep(
            title: "Method 2: Import from YouTube",
            subtitle: "Download and customize YouTube videos",
            content: "Click 'Import from YouTube', paste any YouTube URL, and WallMotion will download the video. You can then select a specific time range (recommended: 30-60 seconds) for optimal wallpaper performance.",
            icon: "play.rectangle.on.rectangle.fill",
            imagePlaceholder: "3tutorial",
            stepType: .usage
        ),
        
        TutorialStep(
            title: "Set as Wallpaper",
            subtitle: "Apply your custom video wallpaper",
            content: "After selecting your video, click 'Set as Wallpaper'. WallMotion will request administrator permission (one time only) to replace the system wallpaper files. Your custom video will immediately become your new live wallpaper!",
            icon: "sparkles",
            imagePlaceholder: "", // No image for this step
            stepType: .usage
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            if !isInSidebar {
                headerSection
            }
            
            // Main content with fixed height
            contentSection
                .frame(maxHeight: .infinity)
            
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
                
                VStack(spacing: 8) {
                    Text("WallMotion Setup Tutorial")
                        .font(.title)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                    
                    Text("Complete setup in 5 minutes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, isInSidebar ? 20 : 40)
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress indicator with phase
                progressIndicator
                
                // Current step content - FIXED HEIGHT
                currentStepContent
                    .frame(height: isInSidebar ? 500 : 650) // Increased height for larger images
                
                // Step navigation (in sidebar)
                if isInSidebar {
                    stepNavigationButtons
                }
            }
            .padding(.horizontal, isInSidebar ? 20 : 40)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
    }
    
    private var progressIndicator: some View {
        VStack(spacing: 12) {
            HStack {
                let currentPhase = getCurrentPhase()
                Text("\(currentPhase.title) - Step \(currentStep + 1) of \(tutorialSteps.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(Double(currentStep + 1) / Double(tutorialSteps.count) * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(currentPhase.color)
            }
            
            ProgressView(value: Double(currentStep + 1), total: Double(tutorialSteps.count))
                .progressViewStyle(LinearProgressViewStyle(tint: getCurrentPhase().color))
                .scaleEffect(y: 1.5)
        }
    }
    
    private var currentStepContent: some View {
        let step = tutorialSteps[currentStep]
        let currentPhase = getCurrentPhase()
        
        return VStack(spacing: 0) {
            // Fixed content area with scroll
            ScrollView {
                VStack(spacing: 16) {
                    // Phase indicator
                    if !isInSidebar {
                        HStack {
                            Image(systemName: currentPhase.icon)
                                .foregroundColor(currentPhase.color)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentPhase.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(currentPhase.color)
                                
                                Text(currentPhase.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(currentPhase.color.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(currentPhase.color.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    
                    // Step icon and title
                    VStack(spacing: 12) {
                        Image(systemName: step.icon)
                            .font(.system(size: isInSidebar ? 30 : 40, weight: .ultraLight))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [currentPhase.color, .purple],
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
                    
                    // Image placeholder (only if imagePlaceholder is not empty)
                    if !step.imagePlaceholder.isEmpty {
                        imagePlaceholder(step.imagePlaceholder, phase: currentPhase)
                    } else {
                        // Special layout for steps without images (like final step)
                        VStack(spacing: 20) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: isInSidebar ? 60 : 80))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            VStack(spacing: 8) {
                                Text("Ready to Apply!")
                                    .font(isInSidebar ? .headline : .title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                
                                Text("Your wallpaper will be set instantly")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(height: isInSidebar ? 180 : 280) // Match image container height
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    
                    // Step description
                    Text(step.content)
                        .font(isInSidebar ? .caption : .body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, isInSidebar ? 0 : 20)
                    
                    // Special notes for certain steps
                    if currentStep == 1 {
                        specialNote(
                            icon: "exclamationmark.triangle",
                            text: "Must be 'Sonoma Horizon' specifically - other wallpapers won't work!",
                            color: .orange
                        )
                    } else if currentStep == 2 {
                        specialNote(
                            icon: "wifi",
                            text: "Requires internet connection. Download size is approximately 200MB.",
                            color: .blue
                        )
                    } else if currentStep == 5 {
                        specialNote(
                            icon: "lightbulb",
                            text: "You can choose between local file upload or YouTube import - both work great!",
                            color: .green
                        )
                    }
                }
                .padding(isInSidebar ? 12 : 20)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(currentPhase.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func specialNote(icon: String, text: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func imagePlaceholder(_ imageName: String, phase: TutorialPhase) -> some View {
        VStack(spacing: 12) {
            // Image container with much larger size for screenshots
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [phase.color.opacity(0.1), .purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: isInSidebar ? 180 : 280) // Much larger for screenshots
                .overlay(
                    Group {
                        if !imageName.isEmpty, let nsImage = NSImage(named: imageName) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: isInSidebar ? 170 : 270)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        } else {
                            // Fallback to icon when no image name or image not found
                            VStack(spacing: 8) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: isInSidebar ? 30 : 40))
                                    .foregroundColor(phase.color.opacity(0.7))
                                
                                Text("Screenshot will appear here")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(phase.color.opacity(0.3), lineWidth: 1)
                )
            
            // Image label
            if !imageName.isEmpty {
                Text(imageName.replacingOccurrences(of: "tutorial", with: "Tutorial "))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }
    
    // MARK: - Navigation Section (FIXED POSITION)
    
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
            
            // Step dots with phases
            HStack(spacing: 8) {
                ForEach(0..<tutorialSteps.count, id: \.self) { index in
                    let stepPhase = getPhaseForStep(index)
                    Circle()
                        .fill(index == currentStep ? stepPhase.color : .gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentStep ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }
            
            Spacer()
            
            // Next/Complete button
            Button(action: nextStep) {
                HStack {
                    Text(currentStep == tutorialSteps.count - 1 ? "Complete Setup" : "Next")
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
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
    
    private var stepNavigationButtons: some View {
        HStack(spacing: 12) {
            Button(action: previousStep) {
                Image(systemName: "chevron.left")
                    .font(.caption)
            }
            .buttonStyle(TertiaryButtonStyle())
            .disabled(currentStep == 0)
            
            // Compact step dots with phases
            HStack(spacing: 4) {
                ForEach(0..<tutorialSteps.count, id: \.self) { index in
                    let stepPhase = getPhaseForStep(index)
                    Circle()
                        .fill(index == currentStep ? stepPhase.color : .gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            
            Button(action: nextStep) {
                Image(systemName: currentStep == tutorialSteps.count - 1 ? "checkmark" : "chevron.right")
                    .font(.caption)
            }
            .buttonStyle(TertiaryButtonStyle())
        }
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
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
    
    // MARK: - Phase Management
    
    private func getCurrentPhase() -> TutorialPhase {
        return getPhaseForStep(currentStep)
    }
    
    private func getPhaseForStep(_ step: Int) -> TutorialPhase {
        let stepData = tutorialSteps[step]
        switch stepData.stepType {
        case .setup:
            return TutorialPhase(
                title: "Initial Setup",
                subtitle: "Configure macOS wallpaper system",
                color: .blue,
                icon: "gearshape.2"
            )
        case .usage:
            return TutorialPhase(
                title: "Using WallMotion",
                subtitle: "Import and set your videos",
                color: .green,
                icon: "play.rectangle.on.rectangle"
            )
        }
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

// MARK: - Tutorial Models

struct TutorialStep {
    let title: String
    let subtitle: String
    let content: String
    let icon: String
    let imagePlaceholder: String
    let stepType: TutorialStepType
}

enum TutorialStepType {
    case setup      // Initial macOS setup
    case usage      // Using WallMotion
}

struct TutorialPhase {
    let title: String
    let subtitle: String
    let color: Color
    let icon: String
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
    .frame(width: 700, height: 900) // Increased size for larger images
}

#Preview("Sidebar") {
    TutorialView(isInSidebar: true)
        .frame(width: 350, height: 600) // Increased size for larger images
}
