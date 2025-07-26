//
//  AccountDropdownView.swift
//  WallMotion
//
//  Account dropdown menu with user info and license details
//

import SwiftUI

struct AccountDropdownView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var deviceManager: DeviceManager
    @State private var showDropdown = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Menu {
            // User Info Header
            if let user = authManager.user {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.blue)
                        Text(user.email)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                    }
                    
                    Divider()
                    
                    // Device Status
                    HStack {
                        Image(systemName: deviceManager.isRegistered ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(deviceManager.isRegistered ? .green : .orange)
                        Text(deviceManager.isRegistered ? "Device Registered" : "Device Not Registered")
                            .font(.caption)
                    }
                    
                    // License Info
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.purple)
                        Text("License: LIFETIME")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
                
                Divider()
            }
            
            // Menu Items
            Button(action: {
                // Show tutorial action
                print("Show Tutorial tapped")
            }) {
                Label("Show Tutorial", systemImage: "book.circle")
            }
            
            Button(action: {
                // Purchase additional license
                if let url = URL(string: "https://wallmotion.eu/profile") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Label("Purchase Additional License", systemImage: "plus.circle")
            }
            
            Divider()
            
            Button(action: {
                authManager.signOut()
            }) {
                Label("Sign Out", systemImage: "person.crop.circle.badge.minus")
            }
            
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .menuStyle(BorderlessButtonMenuStyle())
    }
}

// MARK: - Account Info Card Component
struct AccountInfoCard: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var deviceManager: DeviceManager
    
    var body: some View {
        if let user = authManager.user {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Account")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Signed in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // User Email
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Email Address")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(user.email)
                            .font(.callout)
                            .fontWeight(.medium)
                            .textSelection(.enabled)
                    }
                    
                    Spacer()
                }
                
                // Device Status
                HStack {
                    Image(systemName: deviceManager.isRegistered ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(deviceManager.isRegistered ? .green : .orange)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Device Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(deviceManager.isRegistered ? "Device Registered" : "Device Not Registered")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(deviceManager.isRegistered ? .green : .orange)
                    }
                    
                    Spacer()
                }
                
                // License Info
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.purple)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("License Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("LIFETIME")
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                            
                            Image(systemName: "infinity")
                                .foregroundColor(.purple)
                                .font(.caption)
                        }
                    }
                    
                    Spacer()
                }
                
                // Device Name (if available)
                let deviceName = deviceManager.getDisplayDeviceName()
                if !deviceName.isEmpty {
                    HStack {
                        Image(systemName: "desktopcomputer")
                            .foregroundColor(.gray)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Device Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(deviceName)
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}
