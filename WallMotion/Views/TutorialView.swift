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

// TutorialView s dependencies jako normální krok tutoriálu

struct TutorialView: View {
    @State private var currentStep = 0
    @StateObject private var dependenciesManager = DependenciesManager()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingInstallationAlert = false
    @State private var installationError: Error?
    
    // 🔧 Diagnostics state variables
    @State private var diagnosticsReport = ""
    @State private var showDiagnostics = false
    @State private var isRunningDiagnostics = false
    @State private var diagnosticsSuccess: Bool?
    
    let onComplete: (() -> Void)?
    let isInSidebar: Bool
    
    init(onComplete: (() -> Void)? = nil, isInSidebar: Bool = false) {
        self.onComplete = onComplete
        self.isInSidebar = isInSidebar
    }
    
    // ZMĚNA: Fixní tutorial steps - dependencies jako normální krok
    private let tutorialSteps: [TutorialStep] = [
        // NOVÝ: Dependencies krok jako první step
        TutorialStep(
            title: "Install Required Dependencies",
            subtitle: "Set up tools for YouTube video import",
            content: "To use YouTube import feature, WallMotion needs some command-line tools. Click the install button below to automatically set up Homebrew, yt-dlp, and FFmpeg. This is optional - you can skip this step if you only want to use local video files.",
            icon: "terminal.fill",
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
        .sheet(isPresented: $showDiagnostics) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Diagnostics Report")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("System configuration and compatibility check")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("✕") {
                        showDiagnostics = false
                    }
                    .buttonStyle(PlainButtonStyle())
                    .font(.title3)
                    .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Report content
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(diagnosticsReport)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                            )
                    }
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Copy to Clipboard") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(diagnosticsReport, forType: .string)
                        
                        // Visual feedback
                        let originalTitle = "Copy to Clipboard"
                        // Could add temporary "Copied!" feedback here
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Spacer()
                    
                    Button("Close") {
                        showDiagnostics = false
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(24)
            .frame(width: 700, height: 500)
        }
    }
    
    
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
            
            // ZMĚNA: Dependency step jako normální step
            if currentStep == 0 {
                dependencySection(step: step, phase: currentPhase)
            } else if !step.imagePlaceholder.isEmpty {
                imagePlaceholder(step.imagePlaceholder, phase: currentPhase)
            } else if step.icon == "checkmark.circle.fill" {
                // Final step layout
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
            
            // Step description
            Text(step.content)
                .font(isInSidebar ? .caption : .body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .padding(.horizontal, isInSidebar ? 0 : 20)
        }
    }
    
    // PŘIDEJTE TYTO FUNKCE DO TutorialView struktury:

    private func runFullDiagnostics() {
        isRunningDiagnostics = true
        diagnosticsSuccess = nil
        
        Task {
            do {
                // Simulate some processing time for better UX
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                let report = dependenciesManager.performDiagnostics()
                let (processSuccess, processOutput) = await dependenciesManager.testExternalProcess()
                
                let fullReport = """
                🔍 WallMotion System Diagnostics Report
                Generated: \(Date().formatted(date: .abbreviated, time: .standard))
                ================================================
                
                \(report)
                
                🧪 External Process Test:
                Status: \(processSuccess ? "✅ PASSED" : "❌ FAILED")
                \(processOutput)
                
                ================================================
                📋 Copy this report when contacting support
                """
                
                await MainActor.run {
                    diagnosticsReport = fullReport
                    diagnosticsSuccess = processSuccess
                    isRunningDiagnostics = false
                    showDiagnostics = true
                }
                
            } catch {
                await MainActor.run {
                    diagnosticsReport = "❌ Diagnostics failed: \(error.localizedDescription)"
                    diagnosticsSuccess = false
                    isRunningDiagnostics = false
                    showDiagnostics = true
                }
            }
        }
    }

    private func testSystemPermissions() {
        Task {
            let (success, output) = await dependenciesManager.testExternalProcess()
            
            await MainActor.run {
                let report = """
                🔒 Quick Permission Test
                Generated: \(Date().formatted(date: .omitted, time: .standard))
                
                External Process Test: \(success ? "✅ PASSED" : "❌ FAILED")
                
                Details:
                \(output)
                
                \(success ? "✅ Your system allows WallMotion to run external tools." : "❌ Permission issues detected. External tools may not work properly.")
                """
                
                diagnosticsReport = report
                diagnosticsSuccess = success
                showDiagnostics = true
            }
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
                                    
                                    Button("Skip This Step") {
                                        // Uživatel může přeskočit dependencies
                                        nextStep()
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                }
                                
                                Text("The automatic installer will download and install Homebrew, yt-dlp, and FFmpeg for you. You can skip this step if you only want to use local video files.")
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
            // 🔧 SYSTEM DIAGNOSTICS SECTION
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.vertical, 8)
                    
                    HStack {
                        Image(systemName: "stethoscope")
                            .foregroundColor(.blue)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("System Diagnostics")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Check system configuration and permissions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let success = diagnosticsSuccess {
                            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(success ? .green : .red)
                                .font(.title3)
                        }
                    }
                    
                    // Diagnostic buttons
                    HStack(spacing: 12) {
                        Button(action: runFullDiagnostics) {
                            HStack(spacing: 8) {
                                if isRunningDiagnostics {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                }
                                Text(isRunningDiagnostics ? "Running..." : "Run Full Scan")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isRunningDiagnostics)
                        
                        Button(action: testSystemPermissions) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.circle.fill")
                                Text("Test Permissions")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(isRunningDiagnostics)
                    }
                    
                    // Quick status overview
                    if !diagnosticsReport.isEmpty && !isRunningDiagnostics {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Scan Results:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Button(action: { showDiagnostics = true }) {
                                HStack {
                                    Text("View Detailed Report")
                                        .font(.caption)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                }
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    
                    // Help text
                    Text("💡 Having issues? Run diagnostics to generate a detailed report you can share with support.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
            }
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
    
    // MARK: - Installation Methods
    
    private func tryInstallDependencies() async {
        do {
            try await dependenciesManager.installDependencies()
            // Po úspěšné instalaci refresh status
            dependenciesManager.refreshStatus()
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
        
        After installation, you can continue with the tutorial.
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
}

// MARK: - Support Views zůstávají stejné...

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

