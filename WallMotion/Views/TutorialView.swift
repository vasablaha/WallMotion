//
//  TutorialView.swift
//  WallMotion - Refactored for Bundle-Only Dependencies
//
//  Tutorial component for first-time setup with simplified dependencies
//

import SwiftUI

struct TutorialView: View {
    @State private var currentStep = 0
    @EnvironmentObject private var dependenciesManager: DependenciesManager
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: AuthenticationManager
    
    // Simplified state - no installation needed
    @State private var bundleStatus: DependenciesManager.DependencyStatus?
    @State private var showingDiagnostics = false
    
    let onComplete: (() -> Void)?
    let isInSidebar: Bool
    
    init(onComplete: (() -> Void)? = nil, isInSidebar: Bool = false) {
        self.onComplete = onComplete
        self.isInSidebar = isInSidebar
    }
    
    // REFACTORED: Simplified tutorial steps without installation
    private let tutorialSteps: [TutorialStep] = [
        // INFO: Bundle tools verification (replaces installation step)
        TutorialStep(
            title: "YouTube Import Tools",
            subtitle: "Check bundled video processing tools",
            content: "WallMotion includes bundled tools (yt-dlp, ffmpeg) for YouTube video import. These tools are automatically available - no installation required! You can use the diagnostics to verify they're working properly.",
            icon: "cube.box.fill",
            imagePlaceholder: "",
            stepType: .setup
        ),
        
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
            icon: "arrow.uturn.left.circle.fill",
            imagePlaceholder: "",
            stepType: .setup
        ),
        
        TutorialStep(
            title: "Import Your First Video",
            subtitle: "Choose from file or YouTube",
            content: "Click 'Choose Video File' to select a local video, or 'Import from YouTube' to download a video from YouTube. WallMotion will automatically process and optimize your video for use as a wallpaper.",
            icon: "plus.circle.fill",
            imagePlaceholder: "2tutorial",
            stepType: .usage
        ),
        
        TutorialStep(
            title: "Process & Apply",
            subtitle: "Optimize and set your wallpaper",
            content: "After selecting your video, WallMotion will process it (resize, optimize, etc.) and replace the system wallpaper files. The process is automatic and usually takes 30-60 seconds.",
            icon: "gear.circle.fill",
            imagePlaceholder: "3tutorial",
            stepType: .usage
        ),
        
        TutorialStep(
            title: "You're All Set!",
            subtitle: "Enjoy your new video wallpaper",
            content: "Congratulations! Your video wallpaper is now active. You can return to WallMotion anytime to change to different videos. The app will remember your setup and make future wallpaper changes quick and easy.",
            icon: "checkmark.circle.fill",
            imagePlaceholder: "4tutorial",
            stepType: .usage
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressIndicator
            
            // Main content
            if isInSidebar {
                compactTutorialContent
            } else {
                fullTutorialContent
            }
        }
        .background(backgroundGradient)
        .onAppear {
            // Initialize bundled tools when tutorial appears
            Task {
                await dependenciesManager.initializeBundledExecutables()
                bundleStatus = dependenciesManager.checkDependencies()
            }
        }
        .sheet(isPresented: $showingDiagnostics) {
            DependencyDiagnosticsView()
                .frame(width: 700, height: 600)
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack {
            ForEach(0..<tutorialSteps.count, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentStep ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                
                if index < tutorialSteps.count - 1 {
                    Rectangle()
                        .fill(index < currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }
    
    // MARK: - Full Tutorial Content
    
    private var fullTutorialContent: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Current step content
            currentStepView
            
            Spacer()
            
            // Navigation buttons
            navigationButtons
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }
    
    // MARK: - Compact Tutorial Content (for sidebar)
    
    private var compactTutorialContent: some View {
        VStack(spacing: 20) {
            currentStepHeaderCompact
            
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text(currentTutorialStep.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Show bundle status for first step
                    if currentStep == 0 {
                        bundleStatusSection
                    }
                }
                .padding(.horizontal, 16)
            }
            
            compactNavigationButtons
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Current Step View
    
    private var currentStepView: some View {
        VStack(spacing: 30) {
            // Step icon and phase info
            VStack(spacing: 20) {
                // Phase indicator
                phaseIndicator
                
                // Step icon
                Image(systemName: currentTutorialStep.icon)
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: getCurrentPhase().color == .blue ? [.blue, .cyan] : [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Step content
            VStack(spacing: 16) {
                Text(currentTutorialStep.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .multilineTextAlignment(.center)
                
                Text(currentTutorialStep.subtitle)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(currentTutorialStep.content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 600)
            
            // Special content for first step (bundle tools)
            if currentStep == 0 {
                bundleStatusSection
            }
        }
    }
    
    // MARK: - Bundle Status Section
    
    private var bundleStatusSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Bundled Tools Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Run Diagnostics") {
                    showingDiagnostics = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            if let status = bundleStatus {
                VStack(spacing: 8) {
                    bundleToolRow("yt-dlp", status.ytdlp)
                    bundleToolRow("ffmpeg", status.ffmpeg)
                    bundleToolRow("ffprobe", status.ffprobe)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                )
                
                if status.allAvailable {
                    Text("✅ All YouTube import tools are ready!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                } else {
                    VStack(spacing: 8) {
                        Text("⚠️ Some tools may need initialization")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        Button("Fix Bundle Tools") {
                            Task {
                                await dependenciesManager.initializeBundledExecutables()
                                bundleStatus = dependenciesManager.checkDependencies()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            } else {
                ProgressView("Checking bundle tools...")
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func bundleToolRow(_ tool: String, _ available: Bool) -> some View {
        HStack {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(available ? .green : .red)
                .font(.caption)
            
            Text(tool)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            if let path = dependenciesManager.findExecutablePath(for: tool) {
                Text("Bundled")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
        }
    }
    
    // MARK: - Header Components
    
    private var currentStepHeaderCompact: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: currentTutorialStep.icon)
                    .font(.title2)
                    .foregroundColor(getCurrentPhase().color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentTutorialStep.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Text(currentTutorialStep.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
    }
    
    private var phaseIndicator: some View {
        let phase = getCurrentPhase()
        
        return HStack(spacing: 8) {
            Image(systemName: phase.icon)
                .font(.caption)
                .foregroundColor(phase.color)
            
            Text(phase.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(phase.color)
            
            Text("•")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(phase.subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(phase.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(phase.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Navigation
    
    private var navigationButtons: some View {
        HStack(spacing: 20) {
            if currentStep > 0 {
                Button("Previous") {
                    previousStep()
                }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.leftArrow, modifiers: [])
            }
            
            Spacer()
            
            Button(currentStep == tutorialSteps.count - 1 ? "Finish" : "Next") {
                nextStep()
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(currentStep == tutorialSteps.count - 1 ? .return : .rightArrow, modifiers: [])
        }
    }
    
    private var compactNavigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button("←") {
                    previousStep()
                }
                .buttonStyle(TertiaryButtonStyle())
            }
            
            Text("\(currentStep + 1) of \(tutorialSteps.count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
            
            Button(currentStep == tutorialSteps.count - 1 ? "✓" : "→") {
                nextStep()
            }
            .buttonStyle(TertiaryButtonStyle())
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Computed Properties
    
    private var currentTutorialStep: TutorialStep {
        guard currentStep >= 0 && currentStep < tutorialSteps.count else {
            return tutorialSteps[0]
        }
        return tutorialSteps[currentStep]
    }
    
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
    
    // MARK: - Navigation Methods
    
    private func nextStep() {
        if currentStep < tutorialSteps.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } else {
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
    
    // MARK: - Phase Management
    
    private func getCurrentPhase() -> TutorialPhase {
        return getPhaseForStep(currentStep)
    }
    
    private func getPhaseForStep(_ step: Int) -> TutorialPhase {
        guard step >= 0 && step < tutorialSteps.count else {
            return TutorialPhase(
                title: "Setup",
                subtitle: "Getting started",
                color: .blue,
                icon: "gearshape.2"
            )
        }
        
        let stepData = tutorialSteps[step]
        switch stepData.stepType {
        case .setup:
            return TutorialPhase(
                title: "Initial Setup",
                subtitle: "Configure system and dependencies",
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
}

// MARK: - Tutorial Models (unchanged)

struct TutorialStep {
    let title: String
    let subtitle: String
    let content: String
    let icon: String
    let imagePlaceholder: String
    let stepType: TutorialStepType
}

enum TutorialStepType {
    case setup
    case usage
}

struct TutorialPhase {
    let title: String
    let subtitle: String
    let color: Color
    let icon: String
}


