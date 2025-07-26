//
//  SimpleVideoSaverView.swift
//  WallMotion
//
//  OPRAVENÉ TYPE-CHECK PROBLÉMY
//

import SwiftUI

struct SimpleVideoSaverView: View {
    @ObservedObject var simpleVideoSaverManager: SimpleVideoSaverManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showTooltip = false
    @State private var isEnabled = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            titleSection
            mainContentSection
        }
        .padding(.vertical)
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        HStack {
            Text("VideoSaver Agent")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Main Content Section
    private var mainContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusRow
            descriptionSection
            messageSection
        }
        .padding()
        .background(backgroundView)
        .padding(.horizontal)
    }
    
    // MARK: - Status Row
    private var statusRow: some View {
        HStack {
            statusIcon
            infoSection
            Spacer()
            toggleSection
        }
    }
    
    // MARK: - Status Icon
    private var statusIcon: some View {
        let iconName = isEnabled ? "checkmark.circle.fill" : "exclamationmark.circle"
        let iconColor: Color = isEnabled ? .green : .orange
        
        return Image(systemName: iconName)
            .foregroundColor(iconColor)
            .font(.title2)
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            titleRow
            statusText
        }
    }
    
    private var titleRow: some View {
        HStack(spacing: 6) {
            Text("VideoSaver Running")
                .font(.subheadline)
                .fontWeight(.medium)
            
            infoButton
        }
    }
    
    private var infoButton: some View {
        Button(action: {
            showTooltip.toggle()
        }) {
            Image(systemName: "questionmark.circle")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showTooltip, arrowEdge: .bottom) {
            tooltipView
        }
    }
    
    private var statusText: some View {
        Text(isEnabled ? "Ready" : "Stopped")
            .font(.caption)
            .foregroundColor(isEnabled ? .green : .orange)
    }
    
    // MARK: - Toggle Section
    private var toggleSection: some View {
        Toggle("", isOn: $isEnabled)
            .toggleStyle(SwitchToggleStyle())
            .onChange(of: isEnabled) { newValue in

                simpleVideoSaverManager.toggleVideoSaverAgent(newValue)
                print("VideoSaver toggle: \(newValue)")
            }
    }
    
    // MARK: - Description Section
    private var descriptionSection: some View {
        let enabledText = "VideoSaver Agent automatically refreshes your video wallpapers when macOS freezes them."
        let disabledText = "VideoSaver Agent is disabled. Enable to automatically refresh wallpapers after sleep/wake cycles."
        let description = isEnabled ? enabledText : disabledText
        
        return Text(description)
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
    }
    
    // MARK: - Message Section
    @ViewBuilder
    private var messageSection: some View {
        // No message for now - add when connecting to real manager
        EmptyView()
    }
    
    // MARK: - Background View
    private var backgroundView: some View {
        let fillColor: Color = colorScheme == .dark ?
            Color.gray.opacity(0.1) : Color.gray.opacity(0.05)
        
        return RoundedRectangle(cornerRadius: 12)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
    }
    
    // MARK: - Tooltip View
    private var tooltipView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                tooltipItem(
                    title: "🤔 WHAT IS THIS?",
                    text: "VideoSaver Agent automatically refreshes video wallpapers when macOS freezes them."
                )
                
                tooltipItem(
                    title: "🔧 HOW IT WORKS:",
                    text: "Runs silently in background, detects when video wallpapers stop playing, automatically refreshes frozen wallpapers."
                )
                
                tooltipItem(
                    title: "💡 TIP:",
                    text: "Most users benefit from keeping this enabled."
                )
            }
        }
        .padding(16)
        .frame(width: 350, height: 250)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func tooltipItem(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(text)
                .font(.caption)
        }
    }
}
