// Aktualizace LoginView.swift s success státem a automatickým zavřením

import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var deviceManager = DeviceManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var isShowingSuccess = false
    @State private var countdownTimer: Timer?
    @State private var secondsRemaining = 10
    
    var body: some View {
        VStack(spacing: 0) {
            if isShowingSuccess {
                // Success state
                successView
            } else {
                // Normal login state
                VStack(spacing: 0) {
                    headerSectionWithClose
                    mainContentSection
                    footerSectionWithQuit
                }
            }
        }
        .frame(width: 500)
        .frame(minHeight: 480, maxHeight: 650)
        .background(backgroundGradient)
        .cornerRadius(20)
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth && authManager.hasValidLicense {
                showSuccessAndStartCountdown()
            }
        }
        .onDisappear {
            countdownTimer?.invalidate()
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
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 30) {
            // Success header
            VStack(spacing: 20) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(.green.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 8) {
                    Text("Sign In Successful!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    if let user = authManager.user {
                        Text("Welcome back, \(user.email)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Device info
            deviceInfoSuccessCard
            
            // License info
            if let user = authManager.user {
                licenseInfoSuccessCard(user)
            }
            
            // Countdown and close button
            VStack(spacing: 15) {
                HStack {
                    Text("This window will close automatically in \(secondsRemaining) seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Close Now") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var deviceInfoSuccessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "laptopcomputer")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("Device Information")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Name:")
                        .foregroundColor(.secondary)
                    Text(deviceManager.getDisplayDeviceName())  // ZMĚNA: použití displayName
                        .fontWeight(.medium)
                }
                
                // Zobrazit původní název, pokud má vlastní deviceDisplayName
                if let device = deviceManager.deviceInfo,
                   device.deviceDisplayName != nil {
                    HStack {
                        Text("Original:")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(device.name)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
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
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Registered")
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }
            .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue.opacity(0.05))
                .stroke(.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func licenseInfoSuccessCard(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                Text("License Information")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Type:")
                        .foregroundColor(.secondary)
                    Text("Lifetime License")
                        .fontWeight(.medium)
                        .foregroundColor(.green)
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
                .fill(.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Helper Functions
    
    private func showSuccessAndStartCountdown() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isShowingSuccess = true
        }
        
        // Start countdown
        secondsRemaining = 10
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                countdownTimer?.invalidate()
                dismiss()
            }
        }
    }
    
    // MARK: - Original Login Views (unchanged)
    
    private var headerSectionWithClose: some View {
        VStack(spacing: 15) {
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
            deviceInfoCard
            authenticationSection
            
            if let error = authManager.authError {
                errorCard(error)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
    }
    
    private var footerSectionWithQuit: some View {
        VStack(spacing: 12) {
            Button("Quit WallMotion") {
                NSApplication.shared.terminate(nil)
            }
            .foregroundColor(.red)
            .font(.caption)
            
            HStack(spacing: 20) {
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
            
            Text("© 2025 WallMotion")
                .font(.caption2)
                .foregroundColor(.blue)
        }
        .padding(.bottom, 20)
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
                    Text(deviceManager.getDisplayDeviceName())  // ZMĚNA: použití displayName
                        .fontWeight(.medium)
                }
                
                // Zobrazit původní název, pokud má vlastní deviceDisplayName
                if let device = deviceManager.deviceInfo,
                   device.deviceDisplayName != nil {
                    HStack {
                        Text("Original:")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(device.name)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
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
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    
    private var authenticationSection: some View {
        VStack(spacing: 15) {
            if authManager.isAuthenticated {
                authenticatedState
            } else {
                unauthenticatedState
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
}
