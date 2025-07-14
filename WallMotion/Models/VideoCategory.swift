//
//  VideoCategory.swift
//  WallMotion
//
//  Created by Václav Blaha on 13.07.2025.
//

import SwiftUI

enum VideoCategory: String, CaseIterable {
    case nature = "Nature"
    case abstract = "Abstract"
    case ocean = "Ocean"
    case space = "Space"
    case minimal = "Minimal"
    case custom = "Custom"
    
    var icon: String {
        switch self {
        case .nature: return "leaf.fill"
        case .abstract: return "circle.hexagongrid.fill"
        case .ocean: return "water.waves"
        case .space: return "moon.stars.fill"
        case .minimal: return "circle.fill"
        case .custom: return "folder.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .nature: return .green
        case .abstract: return .purple
        case .ocean: return .blue
        case .space: return .indigo
        case .minimal: return .gray
        case .custom: return .orange
        }
    }
}
