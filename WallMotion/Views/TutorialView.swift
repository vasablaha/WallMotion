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
            
            // Main content area
            if isInSidebar {
                compactTutorialContent
            } else {
                fullTutorialContent
            }
            
            // FIXED: Vždy zobrazená navigace dole
            navigationFooter
        }
        .background(backgroundGradient)
        .onAppear {
            print("📱 TutorialView appeared - Step: \(currentStep)/\(tutorialSteps.count)")
            // Initialize bundled tools when tutorial appears
            Task {
                await dependenciesManager.initializeBundledExecutables()
                bundleStatus = dependenciesManager.checkDependencies()
            }
        }
        .onChange(of: currentStep) { oldValue, newValue in
            print("📝 Step changed: \(oldValue) → \(newValue)")
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
                Button(action: {
                    // ADDED: Direct step navigation
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = index
                    }
                }) {
                    Circle()
                        .fill(index <= currentStep ?
                              LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                              LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: index == currentStep ? 16 : 12, height: index == currentStep ? 16 : 12)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: index == currentStep ? 3 : 0)
                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0.5)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                
                if index < tutorialSteps.count - 1 {
                    Rectangle()
                        .fill(index < currentStep ?
                              LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                              LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 3)
                        .cornerRadius(1.5)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
        }
        .padding(.horizontal, 50)
        .padding(.vertical, 24)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 0)
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor))
                .opacity(0.3),
            alignment: .bottom
        )
    }
    
    // MARK: - Full Tutorial Content
    
    private var fullTutorialContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Current step content with proper centering
                VStack(spacing: 40) {
                    currentStepView
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
                .padding(.vertical, 60)
            }
        }
    }
    
    // MARK: - Compact Tutorial Content (for sidebar)
    
    private var compactTutorialContent: some View {
        VStack(spacing: 16) {
            currentStepHeaderCompact
            
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text(currentTutorialStep.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    /*
                    // Show bundle status for first step
                    if currentStep == 0 {
                        compactBundleStatusSection
                    }
                     */
                }
                .padding(.horizontal, 16)
            }
            
            Spacer(minLength: 60) // Space for navigation
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Current Step View
    
    private var currentStepView: some View {
        VStack(spacing: 50) {
            // Phase indicator - consistent position
            phaseIndicator
            
            // Step icon - consistent size
            Image(systemName: currentTutorialStep.icon)
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: getCurrentPhase().color == .blue ? [.blue, .cyan] : [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 80) // Fixed height for icon
            
            // Step content - consistent container
            VStack(spacing: 20) {
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
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
                    .lineSpacing(2)
            }
            .frame(maxWidth: 700) // Consistent max width
            
            // Special content section for step 0 only
            /*
            if currentStep == 0 {
                bundleStatusSection
            }
             */
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Bundle Status Section
    
    private var bundleStatusSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Bundled Tools Status")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Run Diagnostics") {
                    showingDiagnostics = true
                }
                .buttonStyle(CustomSecondaryButtonStyle())
            }
            
            if let status = bundleStatus {
                VStack(spacing: 10) {
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
                                .stroke(Color(.separatorColor), lineWidth: 1)
                        )
                )
                
                if status.allAvailable {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All YouTube import tools are ready!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 4)
                } else {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Some tools may need initialization")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                        
                        Button("Fix Bundle Tools") {
                            Task {
                                await dependenciesManager.initializeBundledExecutables()
                                bundleStatus = dependenciesManager.checkDependencies()
                            }
                        }
                        .buttonStyle(CustomPrimaryButtonStyle())
                    }
                    .padding(.top, 4)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    
                    Text("Checking bundle tools...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: 600) // Consistent width
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
    
    private var compactBundleStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Tools Status")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Diagnostics") {
                    showingDiagnostics = true
                }
                .buttonStyle(CustomTertiaryButtonStyle())
            }
            
            if let status = bundleStatus {
                VStack(spacing: 6) {
                    bundleToolRow("yt-dlp", status.ytdlp)
                    bundleToolRow("ffmpeg", status.ffmpeg)
                    bundleToolRow("ffprobe", status.ffprobe)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
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
                
                Text("\(currentStep + 1)/\(tutorialSteps.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(getCurrentPhase().color.opacity(0.15))
                    )
            }
        }
        .padding(.horizontal, 16)
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
    
    // MARK: - FIXED Navigation Footer
    
    private var navigationFooter: some View {
        HStack(spacing: 20) {
            // Previous button - completely custom
            Button(action: previousStep) {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Previous")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(currentStep > 0 ? .primary : .secondary)
                .frame(minWidth: 100)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(currentStep > 0 ? Color(.controlBackgroundColor) : Color.clear)
                        .stroke(currentStep > 0 ? Color(.separatorColor) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle()) // REMOVES ALL DEFAULT STYLING
            .disabled(currentStep == 0)
            .keyboardShortcut(.leftArrow, modifiers: [])
            
            Spacer()
            
            // Step counter - simple design
            VStack(spacing: 4) {
                Text("STEP")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                Text("\(currentStep + 1) of \(tutorialSteps.count)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.quaternaryLabelColor).opacity(0.3))
            )
            
            Spacer()
            
            // Next/Finish button - completely custom
            Button(action: nextStep) {
                HStack(spacing: 10) {
                    Text(currentStep == tutorialSteps.count - 1 ? "Finish" : "Next")
                        .font(.system(size: 16, weight: .semibold))
                    Image(systemName: currentStep == tutorialSteps.count - 1 ? "checkmark.circle.fill" : "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(minWidth: 100)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: currentStep == tutorialSteps.count - 1 ?
                                    [.green, .mint] : [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(PlainButtonStyle()) // REMOVES ALL DEFAULT STYLING
            .keyboardShortcut(currentStep == tutorialSteps.count - 1 ? .return : .rightArrow, modifiers: [])
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(
            .regularMaterial,
            in: Rectangle()
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separatorColor))
                .opacity(0.6),
            alignment: .top
        )
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
    
    // MARK: - Navigation Methods (FIXED)
    
    private func nextStep() {
        print("🔄 nextStep called - current: \(currentStep), total: \(tutorialSteps.count)")
        
        if currentStep < tutorialSteps.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep += 1
            }
            print("➡️ Moved to step: \(currentStep)")
        } else {
            print("🏁 Tutorial completed - calling onComplete")
            onComplete?()
        }
    }
    
    private func previousStep() {
        print("🔄 previousStep called - current: \(currentStep)")
        
        if currentStep > 0 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep -= 1
            }
            print("⬅️ Moved to step: \(currentStep)")
        } else {
            print("⚠️ Already at first step")
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
    case setup
    case usage
}

struct TutorialPhase {
    let title: String
    let subtitle: String
    let color: Color
    let icon: String
}

// MARK: - CUSTOM BUTTON STYLES (UPDATED for better macOS look)

struct CustomPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            )
            .foregroundColor(.white)
            .font(.system(size: 15, weight: .semibold))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CustomSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
            )
            .foregroundColor(.primary)
            .font(.system(size: 14, weight: .medium))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CustomTertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.controlBackgroundColor).opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 0.5)
                    )
            )
            .foregroundColor(.secondary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
