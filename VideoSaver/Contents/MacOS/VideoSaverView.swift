//
//  VideoSaverView.swift
//  WallMotion
//
//  Created by Šimon Filípek on 16.07.2025.
//


import ScreenSaver
import AVFoundation

class VideoSaverView: ScreenSaverView {
    private var player: AVQueuePlayer!
    private var looper: AVPlayerLooper!
    private let userDefaults = ScreenSaverDefaults(forModuleWithName: "com.yourcompany.VideoSaver")!

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        setupPlayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupPlayer()
    }

    private func setupPlayer() {
        // Zjisti cestu k videu z user defaults nebo fallback
        let path = userDefaults.string(forKey: "VideoPath") ?? Bundle.main.path(forResource: "Default", ofType: "mov")!
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let item = AVPlayerItem(url: url)
        player = AVQueuePlayer()
        looper = AVPlayerLooper(player: player, templateItem: item)

        let layer = AVPlayerLayer(player: player)
        layer.frame = bounds
        layer.videoGravity = .resizeAspectFill
        self.layer?.addSublayer(layer)
    }

    override func startAnimation() {
        super.startAnimation()
        player.play()
    }

    override func stopAnimation() {
        player.pause()
        super.stopAnimation()
    }

    override func animateOneFrame() {
        // Looping je zajištěn AVPlayerLooper
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        layer?.sublayers?.forEach { $0.frame = bounds }
    }

    // MARK: - Configuration Sheet
    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        let panel = NSOpenPanel()
        panel.title = "Select Video for Wallpaper"
        panel.allowedFileTypes = ["mov"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            userDefaults.set(url.path, forKey: "VideoPath")
            userDefaults.synchronize()
        }
        return nil
    }
}