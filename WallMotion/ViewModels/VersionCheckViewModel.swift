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
        alert.messageText = latest.forceUpdate ? "Povinná aktualizace" : "Nová verze dostupná"
        
        var message = "Je dostupná nová verze \(latest.version)."
        
        if !latest.releaseNotes.isEmpty {
            message += "\n\nCo je nového:\n"
            message += latest.releaseNotes.prefix(3).map { "• \($0)" }.joined(separator: "\n")
        }
        
        alert.informativeText = message
        alert.alertStyle = latest.forceUpdate ? .critical : .informational
        
        alert.addButton(withTitle: "Stáhnout")
        if !latest.forceUpdate {
            alert.addButton(withTitle: "Později")
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
        VStack(spacing: 8) {
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
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Kontroluji verzi...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Error View
    private func errorView(error: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text("Chyba kontroly verze")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Button("Zkusit znovu") {
                viewModel.checkForUpdates()
            }
            .font(.caption2)
            .foregroundColor(.blue)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Up to Date View
    private func upToDateView(version: String?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Aktuální verze")
                    .font(.caption)
                    .fontWeight(.medium)
                
                if let version = version {
                    Text("v\(version)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Update Available View
    private func updateAvailableView(current: String?, latest: LatestVersionInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(latest.forceUpdate ? .red : .blue)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(latest.forceUpdate ? "Povinná aktualizace" : "Nová verze")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(latest.forceUpdate ? .red : .primary)
                    
                    HStack(spacing: 4) {
                        if let current = current {
                            Text("v\(current)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("v\(latest.version)")
                            .font(.caption2)
                            .foregroundColor(latest.forceUpdate ? .red : .blue)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
            }
            
            Button("Stáhnout aktualizaci") {
                viewModel.downloadUpdate(url: latest.downloadUrl)
            }
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(latest.forceUpdate ? Color.red : Color.blue)
            .cornerRadius(4)
        }
        .padding(8)
        .background((latest.forceUpdate ? Color.red : Color.blue).opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Initial View
    private var initialView: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .font(.caption)
            
            Text("Kontrola verzí...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Preview
#if DEBUG
struct VersionCheckView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            VersionCheckView()
        }
        .padding()
        .frame(width: 300)
    }
}
#endif
