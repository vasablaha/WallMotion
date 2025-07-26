// VersionCheckView.swift
import SwiftUI

class VersionCheckViewModel: ObservableObject {
    @Published var versionInfo: VersionCheckResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager.shared
    
    func checkForUpdates() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await networkManager.checkAppVersion()
                
                await MainActor.run {
                    self.isLoading = false
                    self.versionInfo = response
                    
                    // Zobraz alert pokud je dostupná aktualizace
                    if response.hasUpdate, let latest = response.latest {
                        self.showUpdateAlert(latest: latest)
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    print("Version check failed: \(error)")
                }
            }
        }
    }
    
    private func showUpdateAlert(latest: LatestVersionInfo) {
        let alert = NSAlert()
        alert.messageText = latest.forceUpdate ? "Mandatory update" : "New version available"
        
        var message = "A new version is available \(latest.version)."
        
        if !latest.releaseNotes.isEmpty {
            message += "\n\nCo je nového:\n"
            message += latest.releaseNotes.prefix(3).map { "• \($0)" }.joined(separator: "\n")
        }
        
        alert.informativeText = message
        alert.alertStyle = latest.forceUpdate ? .critical : .informational
        
        alert.addButton(withTitle: "Download")
        if !latest.forceUpdate {
            alert.addButton(withTitle: "Later")
        }
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            self.downloadUpdate(url: latest.downloadUrl)
        } else if latest.forceUpdate {
            // Pokud je povinná aktualizace a uživatel nezvolí stáhnout, ukončit aplikaci
            NSApplication.shared.terminate(nil)
        }
    }
    
    func downloadUpdate(url: String) {
        guard let downloadURL = URL(string: url) else {
            print("Invalid download URL: \(url)")
            return
        }
        
        NSWorkspace.shared.open(downloadURL)
    }
}

struct VersionCheckView: View {
    @StateObject private var viewModel = VersionCheckViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error: error)
            } else if let versionInfo = viewModel.versionInfo {
                if versionInfo.hasUpdate, let latest = versionInfo.latest {
                    updateAvailableView(current: versionInfo.currentVersion, latest: latest)
                } else {
                    upToDateView(version: versionInfo.currentVersion)
                }
            } else {
                // Initial state
                initialView
            }
        }
        .onAppear {
            viewModel.checkForUpdates()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.7)
                .progressViewStyle(CircularProgressViewStyle(tint: Color.white.opacity(0.7)))
            
            Text("I'm checking the version...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.25, green: 0.25, blue: 0.28))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Error View
    private func errorView(error: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color.orange)
                    .font(.system(size: 14, weight: .medium))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version control error")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white)
                    
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            Button("Try again") {
                viewModel.checkForUpdates()
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 0))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.25, green: 0.25, blue: 0.28))
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
    
    // MARK: - Up to Date View
    private func upToDateView(version: String?) -> some View {
        HStack(spacing: 10) {
            // Green checkmark circle jako v screenshotu
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 16, height: 16)
                
                Image(systemName: "checkmark")
                    .foregroundColor(.white)
                    .font(.system(size: 9, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Current version")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white)
                
                if let version = version {
                    Text("v\(version)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.25, green: 0.25, blue: 0.28))
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
    
    // MARK: - Update Available View
    private func updateAvailableView(current: String?, latest: LatestVersionInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                // Status indikátor
                ZStack {
                    Circle()
                        .fill(latest.forceUpdate ? Color.red : Color.orange)
                        .frame(width: 16, height: 16)
                    
                    Image(systemName: latest.forceUpdate ? "exclamationmark" : "arrow.down")
                        .foregroundColor(.white)
                        .font(.system(size: 9, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(latest.forceUpdate ? "Mandatory update" : "New version available")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(latest.forceUpdate ? Color.red : Color.white)
                    
                    HStack(spacing: 6) {
                        if let current = current {
                            Text("v\(current)")
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.7))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundColor(Color.white.opacity(0.5))
                        }
                        
                        Text("v\(latest.version)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(latest.forceUpdate ? Color.red : Color.orange)
                    }
                }
                
                Spacer()
            }
            
            Button("Download the update") {
                viewModel.downloadUpdate(url: latest.downloadUrl)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(latest.forceUpdate ? Color.red : Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.25, green: 0.25, blue: 0.28))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Initial View
    private var initialView: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 16, height: 16)
                
                Image(systemName: "ellipsis")
                    .foregroundColor(Color.white.opacity(0.7))
                    .font(.system(size: 8, weight: .medium))
            }
            
            Text("Version control...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.8))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.22, green: 0.22, blue: 0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview
#if DEBUG
struct VersionCheckView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            VersionCheckView()
        }
        .padding(16)
        .background(Color(red: 0.18, green: 0.18, blue: 0.20))
        .frame(width: 300)
    }
}
#endif
