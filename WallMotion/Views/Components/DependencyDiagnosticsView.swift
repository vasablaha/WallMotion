//
//  DependencyDiagnosticsView.swift
//  WallMotion - Bundle Dependencies Testing
//
//  Comprehensive testing of bundled executables (yt-dlp, ffmpeg, ffprobe)
//

import SwiftUI

struct DependencyDiagnosticsView: View {
    @EnvironmentObject private var dependenciesManager: DependenciesManager
    @EnvironmentObject private var authManager: AuthenticationManager
    
    // MARK: - State
    @State private var isRunningTests = false
    @State private var testResults: [ToolTestResult] = []
    @State private var fullReport = ""
    @State private var showingReport = false
    @State private var testProgress: Double = 0.0
    @State private var currentTestStep = ""
    @State private var overallStatus: TestStatus = .notTested
    
    // MARK: - Models
    struct ToolTestResult {
        let tool: String
        let available: Bool
        let executable: Bool
        let version: String?
        let versionSuccess: Bool
        let functionalTest: Bool
        let functionalTestOutput: String?
        let path: String?
        let fileSize: String?
        let permissions: String?
        let overallStatus: TestStatus
        
        var statusIcon: String {
            switch overallStatus {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .failure: return "xmark.circle.fill"
            case .notTested: return "circle"
            }
        }
        
        var statusColor: Color {
            switch overallStatus {
            case .success: return .green
            case .warning: return .orange
            case .failure: return .red
            case .notTested: return .gray
            }
        }
    }
    
    enum TestStatus {
        case success, warning, failure, notTested
    }
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            
            if isRunningTests {
                testingProgressView
            } else {
                testControlsSection
            }
            
            if !testResults.isEmpty {
                testResultsSection
            }
            
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: 600)
        .sheet(isPresented: $showingReport) {
            reportSheetView
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 15) {
            HStack(spacing: 12) {
                Image(systemName: "cpu")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Bundled Dependencies Diagnostics")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Text("Test and validate bundled tools (yt-dlp, ffmpeg, ffprobe)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Testing Progress View
    private var testingProgressView: some View {
        VStack(spacing: 20) {
            ProgressView(value: testProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 8)
            
            VStack(spacing: 8) {
                Text("Running Diagnostics...")
                    .font(.headline)
                
                Text(currentTestStep)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Test Controls Section
    private var testControlsSection: some View {
        VStack(spacing: 15) {
            // Run Tests Button
            Button(action: {
                Task {
                    await runComprehensiveTests()
                }
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Run Comprehensive Tests")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .controlSize(.large)
            
            // Quick Status Check
            Button(action: {
                quickStatusCheck()
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Quick Status Check")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
    
    // MARK: - Test Results Section
    private var testResultsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Test Results")
                    .font(.headline)
                
                Spacer()
                
                // Overall status indicator
                HStack(spacing: 6) {
                    Image(systemName: overallStatusIcon)
                        .foregroundColor(overallStatusColor)
                    
                    Text(overallStatusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(overallStatusColor)
                }
            }
            
            // Individual tool results
            VStack(spacing: 12) {
                ForEach(testResults, id: \.tool) { result in
                    toolResultCard(result)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("View Full Report") {
                    showingReport = true
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Copy Report") {
                    copyReportToClipboard()
                }
                .buttonStyle(TertiaryButtonStyle())
                
                Spacer()
                
                Button("Re-run Tests") {
                    Task {
                        await runComprehensiveTests()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Tool Result Card
    private func toolResultCard(_ result: ToolTestResult) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Status icon
            Image(systemName: result.statusIcon)
                .font(.title2)
                .foregroundColor(result.statusColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 6) {
                // Tool name and status
                HStack {
                    Text(result.tool)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if let version = result.version {
                        Text(version)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                    }
                }
                
                // Test details
                VStack(alignment: .leading, spacing: 4) {
                    testDetailRow("Available", result.available)
                    testDetailRow("Executable", result.executable)
                    testDetailRow("Version Check", result.versionSuccess)
                    testDetailRow("Functional Test", result.functionalTest)
                }
                .font(.caption)
                
                if let path = result.path {
                    Text("Path: \(path)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(result.statusColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(result.statusColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func testDetailRow(_ label: String, _ success: Bool) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Image(systemName: success ? "checkmark" : "xmark")
                .foregroundColor(success ? .green : .red)
                .font(.caption)
        }
    }
    
    // MARK: - Report Sheet View
    private var reportSheetView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(fullReport)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(16)
                }
            }
            .navigationTitle("Diagnostic Report")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showingReport = false
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Copy") {
                        copyReportToClipboard()
                    }
                }
            }
        }
        .frame(width: 700, height: 600)
    }
    
    // MARK: - Computed Properties
    private var overallStatusIcon: String {
        switch overallStatus {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failure: return "xmark.circle.fill"
        case .notTested: return "circle"
        }
    }
    
    private var overallStatusColor: Color {
        switch overallStatus {
        case .success: return .green
        case .warning: return .orange
        case .failure: return .red
        case .notTested: return .gray
        }
    }
    
    private var overallStatusText: String {
        switch overallStatus {
        case .success: return "All Tests Passed"
        case .warning: return "Some Issues Found"
        case .failure: return "Critical Issues"
        case .notTested: return "Not Tested"
        }
    }
}

// MARK: - Testing Functions
extension DependencyDiagnosticsView {
    
    func quickStatusCheck() {
        let status = dependenciesManager.checkDependencies()
        
        testResults = []
        let tools = ["yt-dlp", "ffmpeg", "ffprobe"]
        
        for tool in tools {
            let available = dependenciesManager.isExecutableAvailable(tool)
            let path = dependenciesManager.findExecutablePath(for: tool)
            
            let result = ToolTestResult(
                tool: tool,
                available: available,
                executable: available,
                version: nil,
                versionSuccess: false,
                functionalTest: false,
                functionalTestOutput: nil,
                path: path,
                fileSize: getFileSize(path: path),
                permissions: getPermissions(path: path),
                overallStatus: available ? .warning : .failure // Warning because no full test
            )
            
            testResults.append(result)
        }
        
        updateOverallStatus()
    }
    
    func runComprehensiveTests() async {
        await MainActor.run {
            isRunningTests = true
            testProgress = 0.0
            testResults = []
            currentTestStep = "Initializing tests..."
        }
        
        // Initialize bundled executables
        await MainActor.run {
            currentTestStep = "Fixing bundled executables..."
            testProgress = 0.1
        }
        
        await dependenciesManager.initializeBundledExecutables()
        
        let tools = ["yt-dlp", "ffmpeg", "ffprobe"]
        let progressStep = 0.8 / Double(tools.count)
        
        var results: [ToolTestResult] = []
        
        for (index, tool) in tools.enumerated() {
            await MainActor.run {
                currentTestStep = "Testing \(tool)..."
                testProgress = 0.2 + Double(index) * progressStep
            }
            
            let result = await testTool(tool)
            results.append(result)
            
            // Short delay for better UX
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        await MainActor.run {
            currentTestStep = "Generating report..."
            testProgress = 0.95
        }
        
        // Generate full report
        fullReport = await generateFullReport(results: results)
        
        await MainActor.run {
            testResults = results
            updateOverallStatus()
            testProgress = 1.0
            currentTestStep = "Tests completed!"
        }
        
        // Hide progress after short delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        await MainActor.run {
            isRunningTests = false
        }
    }
    
    private func testTool(_ tool: String) async -> ToolTestResult {
        // 1. Check availability
        let available = dependenciesManager.isExecutableAvailable(tool)
        let path = dependenciesManager.findExecutablePath(for: tool)
        let executable = available && FileManager.default.isExecutableFile(atPath: path ?? "")
        
        // 2. Get file info
        let fileSize = getFileSize(path: path)
        let permissions = getPermissions(path: path)
        
        // 3. Test version
        var version: String?
        var versionSuccess = false
        
        if executable, let toolPath = path {
            let versionResult = await testVersion(tool: tool, path: toolPath)
            version = versionResult.version
            versionSuccess = versionResult.success
        }
        
        // 4. Functional test
        var functionalTest = false
        var functionalTestOutput: String?
        
        if executable && versionSuccess, let toolPath = path {
            let functionalResult = await testFunctionality(tool: tool, path: toolPath)
            functionalTest = functionalResult.success
            functionalTestOutput = functionalResult.output
        }
        
        // 5. Determine overall status
        let overallStatus: TestStatus
        if !available {
            overallStatus = .failure
        } else if !executable || !versionSuccess {
            overallStatus = .failure
        } else if !functionalTest {
            overallStatus = .warning
        } else {
            overallStatus = .success
        }
        
        return ToolTestResult(
            tool: tool,
            available: available,
            executable: executable,
            version: version,
            versionSuccess: versionSuccess,
            functionalTest: functionalTest,
            functionalTestOutput: functionalTestOutput,
            path: path,
            fileSize: fileSize,
            permissions: permissions,
            overallStatus: overallStatus
        )
    }
    
    private func testVersion(tool: String, path: String) async -> (success: Bool, version: String?) {
        let arguments: [String]
        switch tool {
        case "yt-dlp":
            arguments = ["--version"]
        case "ffmpeg", "ffprobe":
            arguments = ["-version"]
        default:
            arguments = ["--version"]
        }
        
        let (success, output) = await ShellCommandExecutor.run(path, arguments: arguments)
        
        if success {
            // Extract version from output
            let cleanVersion = output.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines).first ?? output
            return (true, String(cleanVersion.prefix(50))) // Limit length
        } else {
            return (false, nil)
        }
    }
    
    private func testFunctionality(tool: String, path: String) async -> (success: Bool, output: String) {
        switch tool {
        case "yt-dlp":
            // Test help command (safer than trying to download)
            let (success, output) = await ShellCommandExecutor.run(path, arguments: ["--help"])
            let isValid = success && output.contains("youtube-dl")
            return (isValid, success ? "Help command successful" : output)
            
        case "ffmpeg":
            // Test with no input (should show usage)
            let (success, output) = await ShellCommandExecutor.run(path, arguments: ["-f", "lavfi", "-i", "testsrc=duration=1:size=320x240:rate=1", "-f", "null", "-"])
            // ffmpeg exits with code 0 for this test
            return (success, success ? "Test pattern generation successful" : output)
            
        case "ffprobe":
            // Test help command
            let (success, output) = await ShellCommandExecutor.run(path, arguments: ["-help"])
            let isValid = success && output.contains("ffprobe")
            return (isValid, success ? "Help command successful" : output)
            
        default:
            return (false, "Unknown tool")
        }
    }
    
    private func generateFullReport(results: [ToolTestResult]) async -> String {
        var report = "🔍 WallMotion Bundle Dependencies - Comprehensive Test Report\n"
        report += String(repeating: "=", count: 65) + "\n\n"
        
        // System info
        report += "🖥️ System Information:\n"
        report += "• Date: \(Date().formatted(date: .complete, time: .shortened))\n"
        report += "• macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        report += "• App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\n"
        
        if let user = authManager.user {
            report += "• User: \(user.email)\n"
        }
        
        report += "\n"
        
        // Bundle info
        report += "📦 Bundle Information:\n"
        report += "• Bundle: \(Bundle.main.bundlePath)\n"
        if let resourcePath = Bundle.main.resourcePath {
            report += "• Resources: \(resourcePath)\n"
        }
        report += "\n"
        
        // Test results
        report += "🧪 Test Results:\n"
        for result in results {
            report += "┌─ \(result.tool.uppercased()) ─\(String(repeating: "─", count: 50 - result.tool.count))\n"
            report += "│ Status: \(result.overallStatus == .success ? "✅ PASS" : result.overallStatus == .warning ? "⚠️ WARN" : "❌ FAIL")\n"
            report += "│ Available: \(result.available ? "✅" : "❌")\n"
            report += "│ Executable: \(result.executable ? "✅" : "❌")\n"
            report += "│ Version Test: \(result.versionSuccess ? "✅" : "❌")\n"
            report += "│ Functional Test: \(result.functionalTest ? "✅" : "❌")\n"
            
            if let path = result.path {
                report += "│ Path: \(path)\n"
            }
            
            if let version = result.version {
                report += "│ Version: \(version)\n"
            }
            
            if let size = result.fileSize {
                report += "│ Size: \(size)\n"
            }
            
            if let permissions = result.permissions {
                report += "│ Permissions: \(permissions)\n"
            }
            
            if let functionalOutput = result.functionalTestOutput {
                report += "│ Test Output: \(functionalOutput.prefix(100))...\n"
            }
            
            report += "└\(String(repeating: "─", count: 60))\n\n"
        }
        
        // Summary
        let passCount = results.filter { $0.overallStatus == .success }.count
        let warnCount = results.filter { $0.overallStatus == .warning }.count
        let failCount = results.filter { $0.overallStatus == .failure }.count
        
        report += "📊 Summary:\n"
        report += "• ✅ Passed: \(passCount)/\(results.count)\n"
        report += "• ⚠️ Warning: \(warnCount)/\(results.count)\n"
        report += "• ❌ Failed: \(failCount)/\(results.count)\n"
        report += "• Overall: \(overallStatusText)\n"
        
        return report
    }
    
    private func getFileSize(path: String?) -> String? {
        guard let path = path else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            if let size = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useMB, .useKB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: size)
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    private func getPermissions(path: String?) -> String? {
        guard let path = path else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            if let permissions = attributes[.posixPermissions] as? NSNumber {
                return String(permissions.uint16Value, radix: 8)
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    private func updateOverallStatus() {
        let allResults = testResults
        
        if allResults.isEmpty {
            overallStatus = .notTested
        } else if allResults.allSatisfy({ $0.overallStatus == .success }) {
            overallStatus = .success
        } else if allResults.contains(where: { $0.overallStatus == .failure }) {
            overallStatus = .failure
        } else {
            overallStatus = .warning
        }
    }
    
    private func copyReportToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullReport, forType: .string)
    }
}
