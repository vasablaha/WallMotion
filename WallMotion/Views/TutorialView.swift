//
//  TutorialView.swift
//  WallMotion
//
//  Tutorial component for first-time setup with fixed layout and images
//

//
//  TutorialView.swift
//  WallMotion
//
//  Tutorial with DependenciesManager integration
//

import SwiftUI

struct TutorialView: View {
    @State private var currentStep = 0
    @StateObject private var dependenciesManager = DependenciesManager()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingInstallationAlert = false
    @State private var installationError: Error?
    
    let onComplete: (() -> Void)?
    let isInSidebar: Bool
    
    init(onComplete: (() -> Void)? = nil, isInSidebar: Bool = false) {
        self.onComplete = onComplete
        self.isInSidebar = isInSidebar
    }
    
    private var tutorialSteps: [TutorialStep] {
        let status = dependenciesManager.checkDependencies()
        
        // If dependencies are missing, insert dependency step at the beginning
        if !status.allInstalled {
            return [dependencyStep] + mainTutorialSteps
        } else {
            return mainTutorialSteps
        }
    }
    
    private var dependencyStep: TutorialStep {
        TutorialStep(
            title: "Install Required Dependencies",
            subtitle: "Set up tools for YouTube video import",
            content: dependenciesManager.getInstallationInstructions(),
            icon: "terminal.fill",
            imagePlaceholder: "",
            stepType: .setup
        )
    }
    
    private let mainTutorialSteps: [TutorialStep] = [
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
            icon: "wand.and.stars",
            imagePlaceholder: "3tutorial",
            stepType: .usage
        ),
        
        TutorialStep(
            title: "Enjoy Your Dynamic Wallpaper!",
            subtitle: "Your custom video is now your wallpaper",
            content: "That's it! Your custom video is now playing as your desktop wallpaper. You can repeat this process anytime to change your wallpaper. Pro tip: Videos work best when they're 10-30 seconds long and loop smoothly.",
            icon: "checkmark.circle.fill",
            imagePlaceholder: "4tutorial",
            stepType: .usage
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundGradient
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Main content
                    ScrollView {
                        VStack(spacing: isInSidebar ? 20 : 30) {
                            stepContent
                        }
                        .padding(.horizontal, isInSidebar ? 20 : 40)
                        .padding(.bottom, 120)
                    }
                    
                    Spacer()
                }
                
                // Fixed navigation at bottom
                VStack {
                    Spacer()
                    navigationSection
                }
            }
        }
        .onAppear {
            dependenciesManager.refreshStatus()
        }
        .alert("Installation Error", isPresented: $showingInstallationAlert) {
            Button("OK") { }
            Button("Try Again") {
                Task {
                    await tryInstallDependencies()
                }
            }
        } message: {
            if let error = installationError {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            let currentPhase = getCurrentPhase()
            
            HStack(spacing: 12) {
                Image(systemName: currentPhase.icon)
                    .font(.title2)
                    .foregroundColor(currentPhase.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentPhase.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(currentPhase.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(currentStep + 1)/\(tutorialSteps.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(currentPhase.color.opacity(0.1))
                    )
            }
            .padding(.horizontal, isInSidebar ? 20 : 40)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Step Content
    
    private var stepContent: some View {
        let step = tutorialSteps[currentStep]
        let currentPhase = getCurrentPhase()
        
        return VStack(spacing: isInSidebar ? 20 : 30) {
            // Phase indicator
            if !isInSidebar {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: currentPhase.icon)
                            .font(.caption)
                            .foregroundColor(currentPhase.color)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentPhase.title)
                                .font(.caption)
                                .fontWeight(.medium)
                            
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
                    
                    Spacer()
                }
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
            
            // Special handling for dependency step
            if step.stepType == .setup && step.icon == "terminal.fill" {
                dependencySection(step: step, phase: currentPhase)
            } else {
                // Regular step content
                if !step.imagePlaceholder.isEmpty {
                    imagePlaceholder(step.imagePlaceholder, phase: currentPhase)
                } else {
                    // Special layout for steps without images (like final step)
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: isInSidebar ? 40 : 60))
                            .foregroundColor(.green)
                        
                        VStack(spacing: 8) {
                            Text("Setup Complete!")
                                .font(isInSidebar ? .headline : .title2)
                                .fontWeight(.bold)
                            
                            Text("You're ready to use WallMotion")
                                .font(isInSidebar ? .caption : .subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Step description
            Text(step.content)
                .font(isInSidebar ? .caption : .body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .padding(.horizontal, isInSidebar ? 0 : 20)
        }
    }
    
    // MARK: - Dependency Section
    
    private func dependencySection(step: TutorialStep, phase: TutorialPhase) -> some View {
        VStack(spacing: 20) {
            let status = dependenciesManager.checkDependencies()
            
            VStack(spacing: 16) {
                // Dependency status badges
                HStack(spacing: 16) {
                    DependencyBadge(name: "Homebrew", isInstalled: status.homebrew)
                    DependencyBadge(name: "yt-dlp", isInstalled: status.ytdlp)
                    DependencyBadge(name: "FFmpeg", isInstalled: status.ffmpeg)
                }
                
                // Installation section
                if !status.allInstalled {
                    VStack(spacing: 16) {
                        if dependenciesManager.isInstalling {
                            // Installation progress
                            VStack(spacing: 12) {
                                ProgressView(value: dependenciesManager.installationProgress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .frame(height: 8)
                                    .scaleEffect(x: 1, y: 1.5)
                                
                                Text(dependenciesManager.installationMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button("Cancel Installation") {
                                    dependenciesManager.cancelInstallation()
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        } else {
                            // Installation buttons
                            VStack(spacing: 12) {
                                Button(action: {
                                    Task {
                                        await tryInstallDependencies()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text("Install Dependencies Automatically")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                
                                HStack {
                                    Button("Manual Instructions") {
                                        showManualInstructions()
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                    
                                    Button("Save Script") {
                                        saveInstallationScript()
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                }
                                
                                Text("The automatic installer will download and install Homebrew, yt-dlp, and FFmpeg for you.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                    }
                } else {
                    // All dependencies installed
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        
                        Text("All dependencies installed!")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                        
                        Text("You can now use YouTube import feature")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func imagePlaceholder(_ imageName: String, phase: TutorialPhase) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(phase.color.opacity(0.05))
                .frame(height: isInSidebar ? 180 : 280)
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
    
    // MARK: - Navigation Section
    
    private var navigationSection: some View {
        HStack(spacing: 20) {
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
            
            HStack(spacing: 8) {
                ForEach(0..<tutorialSteps.count, id: \.self) { index in
                    let stepPhase = getPhaseForStep(index)
                    Circle()
                        .fill(index == currentStep ? stepPhase.color : .gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentStep ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: currentStep)
                }
            }
            
            Spacer()
            
            Button(action: nextStep) {
                HStack {
                    Text(currentStep == tutorialSteps.count - 1 ? "Finish" : "Next")
                    Image(systemName: currentStep == tutorialSteps.count - 1 ? "checkmark" : "chevron.right")
                        .font(.caption)
                }
                .frame(minWidth: 100)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.vertical, 20)
        .padding(.horizontal, isInSidebar ? 20 : 40)
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
    
    // MARK: - Navigation Methods
    
    private func nextStep() {
        // Check if we're on the dependency step and dependencies aren't installed
        if currentStep == 0 && tutorialSteps[currentStep].icon == "terminal.fill" {
            let status = dependenciesManager.checkDependencies()
            if !status.allInstalled {
                // Don't allow proceeding without dependencies
                return
            }
        }
        
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
    
    // MARK: - Installation Methods
    
    private func tryInstallDependencies() async {
        do {
            try await dependenciesManager.installDependencies()
            
            // After successful installation, refresh the tutorial steps
            await MainActor.run {
                dependenciesManager.refreshStatus()
            }
            
        } catch {
            await MainActor.run {
                installationError = error
                showingInstallationAlert = true
            }
        }
    }
    
    private func showManualInstructions() {
        let alert = NSAlert()
        alert.messageText = "Manual Installation Instructions"
        alert.informativeText = """
        To install the dependencies manually:
        
        1. Install Homebrew (if not already installed):
           Open Terminal and run:
           /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        2. Install yt-dlp:
           brew install yt-dlp
        
        3. Install FFmpeg:
           brew install ffmpeg
        
        After installation, click "Next" to continue.
        """
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Copy Commands")
        
        let response = alert.runModal()
        
        if response == .alertSecondButtonReturn {
            let commands = """
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            brew install yt-dlp
            brew install ffmpeg
            """
            
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(commands, forType: .string)
        }
    }
    
    private func saveInstallationScript() {
        do {
            let scriptURL = try dependenciesManager.saveInstallationScript()
            
            let alert = NSAlert()
            alert.messageText = "Installation Script Saved"
            alert.informativeText = """
            The installation script has been saved to:
            \(scriptURL.path)
            
            You can run it in Terminal with:
            bash "\(scriptURL.path)"
            """
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Show in Finder")
            
            let response = alert.runModal()
            
            if response == .alertSecondButtonReturn {
                NSWorkspace.shared.selectFile(scriptURL.path, inFileViewerRootedAtPath: scriptURL.deletingLastPathComponent().path)
            }
            
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error Saving Script"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// MARK: - Support Views

struct DependencyBadge: View {
    let name: String
    let isInstalled: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isInstalled ? .green : .red)
                .font(.caption)
            
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isInstalled ? .green : .red)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((isInstalled ? Color.green : Color.red).opacity(0.1))
        )
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

