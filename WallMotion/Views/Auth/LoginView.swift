//
//  LoginView.swift
//  WallMotion
//
//  Login and authentication screen
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var deviceManager = DeviceManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            headerSectionWithClose
            
            // Main content
            mainContentSection
            
            // Footer with quit option
            footerSectionWithQuit
        }
        .frame(width: 500)
        .frame(minHeight: 480, maxHeight: 650)
        .background(backgroundGradient)
        .cornerRadius(20)
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark ?
                [Color.black.opacity(0.9), Color.blue.opacity(0.2)] :
                [Color.white, Color.blue.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var headerSectionWithClose: some View {
        VStack(spacing: 15) {
            // Close button in top right
            HStack {
                Spacer()
                Button(action: {
                    dismiss()
                }) {
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
                .help("Close")
            }
            .padding(.top, 15)
            .padding(.trailing, 20)
            
            // App icon
            Image(systemName: "desktopcomputer")
                .font(.system(size: 50, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 6) {
                Text("WallMotion")
                    .font(.title)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                
                Text("Premium Live Wallpapers for macOS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
    }
    
    private var mainContentSection: some View {
        VStack(spacing: 15) {
            // Device info
            deviceInfoCard
            
            // Authentication section
            authenticationSection
            
            // Error display
            if let error = authManager.authError {
                errorCard(error)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
    }
    
    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "laptopcomputer")
                    .foregroundColor(.blue)
                Text("This Device")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Name:")
                        .foregroundColor(.secondary)
                    Text(deviceManager.getDeviceName())
                        .fontWeight(.medium)
                }
                
                if let model = deviceManager.getMacModel() {
                    HStack {
                        Text("Model:")
                            .foregroundColor(.secondary)
                        Text(model)
                            .fontWeight(.medium)
                    }
                }
                
                if let macosVersion = deviceManager.getMacOSVersion() {
                    HStack {
                        Text("macOS:")
                            .foregroundColor(.secondary)
                        Text(macosVersion)
                            .fontWeight(.medium)
                    }
                }
                
                HStack {
                    Text("Status:")
                        .foregroundColor(.secondary)
                    
                    if deviceManager.isRegistered {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Registered")
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("Not Registered")
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .font(.caption)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var authenticationSection: some View {
        VStack(spacing: 15) {
            // Single sign in button
            Button {
                Task {
                    await authManager.authenticateWithWeb()
                }
            } label: {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(authManager.isLoading ? "Signing In..." : "Sign In with Web Browser")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(authManager.isLoading)
            
            VStack(spacing: 6) {
                Text("Don't have an account?")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Button("Create Account") {
                    if let url = URL(string: "https://wallmotion.eu/register") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption2)
                .foregroundColor(.blue)
            }
        }
    }
    
    private var authenticatedState: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Signed In")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    if let user = authManager.user {
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.green.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.green.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // License info
            if let user = authManager.user {
                licenseInfoCard(user)
            }
            
            Button("Sign Out") {
                authManager.signOut()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
    
    private var unauthenticatedState: some View {
        VStack(spacing: 15) {
            VStack(spacing: 8) {
                Text("Sign In Required")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Please sign in with your WallMotion account to continue using the app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task {
                    await authManager.authenticateWithWeb()
                }
            }) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "globe")
                    }
                    
                    Text(authManager.isLoading ? "Signing In..." : "Sign In with Web Browser")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(authManager.isLoading)
            .onTapGesture {
                // Clear any previous errors when user tries again
                Task { @MainActor in
                    authManager.authError = nil
                }
            }
            
            VStack(spacing: 6) {
                Text("Don't have an account?")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Button("Create Account") {
                    if let url = URL(string: "https://wallmotion.eu/register") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption2)
                .foregroundColor(.blue)
            }
        }
    }
    
    private func licenseInfoCard(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.blue)
                Text("License Status")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Type:")
                        .foregroundColor(.secondary)
                    Text(user.licenseType == "LIFETIME" ? "Lifetime License" : "No License")
                        .fontWeight(.medium)
                        .foregroundColor(user.licenseType == "LIFETIME" ? .green : .red)
                }
                
                HStack {
                    Text("Devices:")
                        .foregroundColor(.secondary)
                    Text("\(user.licensesCount ?? 0)")
                        .fontWeight(.medium)
                }
                
                if let purchaseDate = user.purchaseDate {
                    HStack {
                        Text("Purchased:")
                            .foregroundColor(.secondary)
                        Text(purchaseDate, style: .date)
                            .fontWeight(.medium)
                    }
                }
            }
            .font(.caption)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func errorCard(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption2)
                
                Text("Authentication Error")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                Spacer()
            }
            
            Text(getReadableError(error))
                .font(.caption2)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func getReadableError(_ error: String) -> String {
        if error.contains("WebAuthenticationSession error 2") || error.contains("presentation context") {
            return "Authentication window could not be displayed. Please try again."
        } else if error.contains("WebAuthenticationSession") {
            return "Browser authentication failed. Please check your internet connection."
        } else if error.contains("Invalid authentication URL") {
            return "Authentication service is temporarily unavailable."
        } else if error.contains("Authentication cancelled") {
            return "Sign in was cancelled. Click 'Sign In with Web Browser' to try again."
        } else {
            return error
        }
    }
    
    private var footerSectionWithQuit: some View {
        VStack(spacing: 8) {
            Text("© 2025 WallMotion")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 15) {
                Button("Support") {
                    if let url = URL(string: "https://wallmotion.eu/support") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption2)
                .foregroundColor(.blue)
                
                Button("Privacy") {
                    if let url = URL(string: "https://wallmotion.eu/privacy") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption2)
                .foregroundColor(.blue)
                
                Button("Terms") {
                    if let url = URL(string: "https://wallmotion.eu/terms") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption2)
                .foregroundColor(.blue)
            }
        }
        .padding(.bottom, 15)
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.primary.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}
