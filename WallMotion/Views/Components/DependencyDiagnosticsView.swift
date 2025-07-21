//
//  DependencyDiagnosticsView.swift
//  WallMotion
//
//  Standalone view for dependency installation and system diagnostics
//

import SwiftUI

struct DependencyDiagnosticsView: View {
    @StateObject private var dependenciesManager = DependenciesManager()
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.colorScheme) private var colorScheme
    
    // Installation state
    @State private var showingInstallationAlert = false
    @State private var installationError: Error?
    
    // Diagnostics state
    @State private var diagnosticsReport = ""
    @State private var showDiagnostics = false
    @State private var isRunningDiagnostics = false
    @State private var diagnosticsSuccess: Bool?
    @State private var lastScanSummary = ""
    @State private var showingScanResults = false
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            dependencyStatusSection
            installationSection
            diagnosticsSection
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
            diagnosticsSheet
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("YouTube Import Setup")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Install tools for downloading and processing YouTube videos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text("To use YouTube import feature, WallMotion needs some command-line tools. This is optional - you can skip this if you only want to use local video files.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
    }
    
    // MARK: - Dependency Status Section
    
    private var dependencyStatusSection: some View {
        let status = dependenciesManager.checkDependencies()
        
        return VStack(spacing: 16) {
            HStack {
                Text("Current Status")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if status.allInstalled {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Ready")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(status.missing.count) Missing")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // Dependency badges
            HStack(spacing: 16) {
                DependencyBadge(name: "Homebrew", isInstalled: status.homebrew)
                DependencyBadge(name: "yt-dlp", isInstalled: status.ytdlp)
                DependencyBadge(name: "FFmpeg", isInstalled: status.ffmpeg)
            }
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
    
    // MARK: - Installation Section
    
    private var installationSection: some View {
        let status = dependenciesManager.checkDependencies()
        
        return VStack(spacing: 16) {
            if !status.allInstalled {
                if dependenciesManager.isInstalling {
                    installationProgressView
                } else {
                    installationButtonsView
                }
            } else {
                installationCompleteView
            }
        }
    }
    
    private var installationProgressView: some View {
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
    }
    
    private var installationButtonsView: some View {
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
                    // Could emit a callback here if needed
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
    
    private var installationCompleteView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("All dependencies installed!")
                .font(.headline)
                .foregroundColor(.green)
            
            Text("YouTube import feature is ready to use.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Diagnostics Section
    
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .padding(.vertical, 8)
            
            diagnosticsHeader
            diagnosticsButtons
            
            if showingScanResults && !isRunningDiagnostics {
                diagnosticsScanResults
            }
            
            diagnosticsHelpText
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
    
    private var diagnosticsHeader: some View {
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
    }
    
    private var diagnosticsButtons: some View {
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
    }
    
    private var diagnosticsScanResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: diagnosticsSuccess == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(diagnosticsSuccess == true ? .green : .orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(diagnosticsSuccess == true ? "System Ready" : "Issues Detected")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(diagnosticsSuccess == true ? .green : .orange)
                    
                    Text(lastScanSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button("View Details") {
                    showDiagnostics = true
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Run Again") {
                    runFullDiagnostics()
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.blue)
                .font(.caption)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((diagnosticsSuccess == true ? Color.green : Color.orange).opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((diagnosticsSuccess == true ? Color.green : Color.orange).opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var diagnosticsHelpText: some View {
        Text("💡 Having issues? Run diagnostics to generate a detailed report you can share with support.")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.top, 4)
    }
    
    // MARK: - Diagnostics Sheet
    
    private var diagnosticsSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            diagnosticsSheetHeader
            Divider()
            diagnosticsStatusIndicator
            diagnosticsReportContent
            diagnosticsSheetFooter
        }
        .padding(24)
        .frame(width: 800, height: 600)
    }
    
    private var diagnosticsSheetHeader: some View {
        HStack {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("System Diagnostics")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Complete technical report for troubleshooting")
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
    }
    
    private var diagnosticsStatusIndicator: some View {
        HStack(spacing: 12) {
            Image(systemName: diagnosticsSuccess == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(diagnosticsSuccess == true ? .green : .orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(diagnosticsSuccess == true ? "System Status: Ready" : "System Status: Issues Detected")
                    .font(.headline)
                    .foregroundColor(diagnosticsSuccess == true ? .green : .orange)
                
                Text("Generated: \(Date().formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((diagnosticsSuccess == true ? Color.green : Color.orange).opacity(0.1))
        )
    }
    
    private var diagnosticsReportContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(diagnosticsReport)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var diagnosticsSheetFooter: some View {
        HStack(spacing: 12) {
            Button("📋 Copy Report") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(diagnosticsReport, forType: .string)
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Text("💡 Tip: Send this report to support if you need help")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button("Close") {
                showDiagnostics = false
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
}

// MARK: - Installation & Diagnostics Functions

extension DependencyDiagnosticsView {
    
    private func tryInstallDependencies() async {
        do {
            try await dependenciesManager.installDependencies()
        } catch {
            await MainActor.run {
                installationError = error
                showingInstallationAlert = true
            }
        }
    }
    
    private func showManualInstructions() {
        dependenciesManager.showManualInstallationInstructions()
    }
    
    private func runFullDiagnostics() {
        isRunningDiagnostics = true
        diagnosticsSuccess = nil
        showingScanResults = false
        
        Task {
            do {
                try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds for better UX
                
                let dependencyReport = dependenciesManager.performDiagnostics()
                let (processSuccess, processOutput) = await dependenciesManager.testExternalProcess()
                let systemInfo = generateSystemInfo()
                let userInfo = generateUserInfo()
                
                // Generate summary for quick view
                let dependencyStatus = dependenciesManager.checkDependencies()
                let summary = createScanSummary(
                    dependenciesOK: dependencyStatus.allInstalled,
                    processTestOK: processSuccess,
                    issueCount: dependencyStatus.missing.count
                )
                
                // Generate detailed report
                let fullReport = """
                🔍 WallMotion Complete System Report
                Generated: \(Date().formatted(date: .complete, time: .standard))
                
                ═══════════════════════════════════════════════════════
                📋 SUMMARY
                ═══════════════════════════════════════════════════════
                Status: \(processSuccess && dependencyStatus.allInstalled ? "✅ SYSTEM READY" : "⚠️ ISSUES DETECTED")
                Dependencies: \(dependencyStatus.allInstalled ? "✅ All installed" : "❌ Missing: \(dependencyStatus.missing.joined(separator: ", "))")
                Permissions: \(processSuccess ? "✅ Working" : "❌ Failed")
                
                ═══════════════════════════════════════════════════════
                🖥️ SYSTEM INFORMATION
                ═══════════════════════════════════════════════════════
                \(systemInfo)
                
                ═══════════════════════════════════════════════════════
                👤 USER INFORMATION
                ═══════════════════════════════════════════════════════
                \(userInfo)
                
                ═══════════════════════════════════════════════════════
                🔧 DEPENDENCY ANALYSIS
                ═══════════════════════════════════════════════════════
                \(dependencyReport)
                
                ═══════════════════════════════════════════════════════
                🧪 PERMISSIONS TEST
                ═══════════════════════════════════════════════════════
                Test Status: \(processSuccess ? "✅ PASSED" : "❌ FAILED")
                \(processOutput)
                
                ═══════════════════════════════════════════════════════
                📞 SUPPORT INFORMATION
                ═══════════════════════════════════════════════════════
                When contacting support, please include this entire report.
                Report ID: WM-\(Date().timeIntervalSince1970.rounded())
                ═══════════════════════════════════════════════════════
                """
                
                await MainActor.run {
                    diagnosticsReport = fullReport
                    lastScanSummary = summary
                    diagnosticsSuccess = processSuccess && dependencyStatus.allInstalled
                    isRunningDiagnostics = false
                    showingScanResults = true
                }
                
            } catch {
                await MainActor.run {
                    diagnosticsReport = "❌ Diagnostics failed: \(error.localizedDescription)"
                    lastScanSummary = "Scan failed: \(error.localizedDescription)"
                    diagnosticsSuccess = false
                    isRunningDiagnostics = false
                    showingScanResults = true
                }
            }
        }
    }
    
    private func testSystemPermissions() {
        Task {
            let (success, output) = await dependenciesManager.testExternalProcess()
            let systemInfo = generateSystemInfo()
            let userInfo = generateUserInfo()
            
            await MainActor.run {
                let summary = success ?
                    "External process permissions are working correctly." :
                    "Permission issues detected. External tools may not work properly."
                
                let report = """
                🔒 WallMotion Permission Check
                Generated: \(Date().formatted(date: .complete, time: .standard))
                
                ═══════════════════════════════════════════════════════
                📋 PERMISSION TEST SUMMARY
                ═══════════════════════════════════════════════════════
                Status: \(success ? "✅ PASSED" : "❌ FAILED")
                \(success ? "✅ Your system allows WallMotion to run external tools." : "❌ Permission issues detected. External tools may not work properly.")
                
                ═══════════════════════════════════════════════════════
                🖥️ SYSTEM INFORMATION
                ═══════════════════════════════════════════════════════
                \(systemInfo)
                
                ═══════════════════════════════════════════════════════
                👤 USER INFORMATION
                ═══════════════════════════════════════════════════════
                \(userInfo)
                
                ═══════════════════════════════════════════════════════
                🧪 DETAILED TEST RESULTS
                ═══════════════════════════════════════════════════════
                \(output)
                
                ═══════════════════════════════════════════════════════
                📞 SUPPORT INFORMATION
                ═══════════════════════════════════════════════════════
                When contacting support, please include this report.
                Report ID: WM-PERM-\(Date().timeIntervalSince1970.rounded())
                ═══════════════════════════════════════════════════════
                """
                
                diagnosticsReport = report
                lastScanSummary = summary
                diagnosticsSuccess = success
                showingScanResults = true
            }
        }
    }
    
    private func createScanSummary(dependenciesOK: Bool, processTestOK: Bool, issueCount: Int) -> String {
        if dependenciesOK && processTestOK {
            return "All systems operational. YouTube import and video processing should work correctly."
        } else if !dependenciesOK && !processTestOK {
            return "Multiple issues found: \(issueCount) missing dependencies and permission problems detected."
        } else if !dependenciesOK {
            return "\(issueCount) dependencies missing. Install them to enable YouTube import features."
        } else {
            return "Permission issues detected. External tools may not work properly in this environment."
        }
    }
    
    private func generateSystemInfo() -> String {
        let processInfo = ProcessInfo.processInfo
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let bundleID = Bundle.main.bundleIdentifier ?? "Unknown"
        
        // Simple architecture detection
        let architecture: String
        #if arch(arm64)
            architecture = "Apple Silicon (ARM64)"
        #elseif arch(x86_64)
            architecture = "Intel (x86_64)"
        #else
            architecture = "Unknown"
        #endif
        
        return """
        • Device: \(processInfo.hostName)
        • macOS Version: \(processInfo.operatingSystemVersionString)
        • Architecture: \(architecture) - \(processInfo.processorCount) cores
        • Memory: \(ByteCountFormatter.string(fromByteCount: Int64(processInfo.physicalMemory), countStyle: .memory))
        • App Version: \(appVersion) (Build \(buildNumber))
        • Bundle ID: \(bundleID)
        • Runtime: \(Int(processInfo.systemUptime)) seconds uptime
        • Environment: \(Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "Sandboxed" : "Development")
        """
    }
    
    private func generateUserInfo() -> String {
        return """
        • Email: \(authManager.user?.email ?? "Not available")  
        • License Status: \(authManager.hasValidLicense ? "✅ Valid" : "❌ Invalid/Missing")
        • Authentication: \(authManager.isAuthenticated ? "✅ Logged in" : "❌ Not logged in")
        • User ID: \(authManager.user?.id ?? "Not available")
        """
    }
}

// MARK: - Supporting Views and Styles

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

