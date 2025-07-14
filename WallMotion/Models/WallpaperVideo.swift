//
//  WallpaperVideo.swift
//  WallMotion
//
//  Created by Václav Blaha on 13.07.2025.
//

import Foundation

struct WallpaperVideo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: VideoCategory
    let duration: String
    let resolution: String
    let thumbnailName: String
    let fileName: String
    let description: String
    
    var isCustom: Bool { fileName.isEmpty }
}
