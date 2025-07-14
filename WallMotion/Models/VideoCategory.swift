//
//  VideoCategory.swift
//  WallMotion
//
//  Created by Václav Blaha on 13.07.2025.
//

import SwiftUI

enum VideoCategory: String, CaseIterable {
    case custom = "Custom Upload"
    case youtube = "YouTube Import" // NEW: YouTube import category
    case f1 = "F1"
    case cars = "Cars"
    case nature = "Nature"
    case drone = "Drone Shots"
    case fairytales = "Fairytales & Animation"
    case anime = "Anime & Manga"
    case aesthetics = "Aesthetic Styles"
    case space = "Space & Cosmos"
    case cyberpunk = "Neon & Cyberpunk"
    case gaming = "Gaming & Pop Culture"
    case mood = "Mood & Vibes"
    case lofi = "Lo-fi & Chill"
    case animals = "Animals"
    case tech = "Technology & Sci-fi"
    case quotes = "Motivational Quotes"
    case colors = "Color Collections"
    case seasonal = "Seasonal"
    case threeD = "3D & Depth"
    
    var icon: String {
        switch self {
        case .custom: return "folder.badge.plus"
        case .youtube: return "play.rectangle.on.rectangle.fill" // NEW
        case .f1: return "car.circle"
        case .cars: return "car.fill"
        case .nature: return "leaf.fill"
        case .drone: return "airplane"
        case .fairytales: return "sparkles"
        case .anime: return "star.circle.fill"
        case .aesthetics: return "circle.hexagongrid.fill"
        case .space: return "moon.stars.fill"
        case .cyberpunk: return "building.2.fill"
        case .gaming: return "gamecontroller.fill"
        case .mood: return "cloud.rain.fill"
        case .lofi: return "headphones"
        case .animals: return "pawprint.fill"
        case .tech: return "cpu.fill"
        case .quotes: return "quote.bubble.fill"
        case .colors: return "paintpalette.fill"
        case .seasonal: return "calendar"
        case .threeD: return "cube.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .custom: return .orange
        case .youtube: return .red // NEW: YouTube red color
        case .f1: return .red
        case .cars: return .gray
        case .nature: return .green
        case .drone: return .blue
        case .fairytales: return .pink
        case .anime: return .purple
        case .aesthetics: return .indigo
        case .space: return .black
        case .cyberpunk: return .cyan
        case .gaming: return .mint
        case .mood: return .brown
        case .lofi: return .yellow
        case .animals: return .orange
        case .tech: return .blue
        case .quotes: return .primary
        case .colors: return .purple
        case .seasonal: return .green
        case .threeD: return .gray
        }
    }
    
    var subcategories: [String] {
        switch self {
        case .custom:
            return []
        case .youtube: // NEW: YouTube subcategories
            return ["Music Videos", "Nature & Travel", "Gaming Content", "Animations", "Tutorials", "Vlogs", "Short Clips", "Live Recordings"]
        case .f1:
            return ["Red Bull Racing", "Mercedes-AMG Petronas", "Ferrari", "McLaren", "Aston Martin", "Alpine", "Williams", "Haas", "AlphaTauri", "Stake (ex-Alfa Romeo)"]
        case .cars:
            return ["Mercedes", "BMW", "Volkswagen", "Lamborghini", "Ferrari", "Audi", "Porsche", "Tesla", "JDM Cars", "Muscle Cars"]
        case .nature:
            return ["Mountains", "Forests", "Ocean & Beaches", "Meadows & Fields", "Deserts", "Sunsets & Sunrises", "Night Sky"]
        case .drone:
            return ["Landscape from Above", "Urban Scenes", "Sea & Coast", "Roads & Cars", "Winter Drone Shots", "Aerial Views"]
        case .fairytales:
            return ["Studio Ghibli Style", "Disney Style", "Pixar Style", "DreamWorks Style", "Fantasy Worlds", "Stylized Castles"]
        case .anime:
            return ["Cyberpunk Anime", "Studio Ghibli", "Naruto", "Jujutsu Kaisen", "Demon Slayer", "Romantic Anime", "Stylized Backgrounds"]
        case .aesthetics:
            return ["Dark Academia", "Light Academia", "Vaporwave/Synthwave", "Minimalist Setup", "Retro/Y2K", "Clean Desk", "Grunge/Indie"]
        case .space:
            return ["Planets", "Stars", "Milky Way", "Astronauts", "Stylized Universe", "Night Sky"]
        case .cyberpunk:
            return ["Night City", "Neon Streets", "Asian Cities", "Futuristic Metropolis", "Glitch Effects", "Blade Runner Style"]
        case .gaming:
            return ["GTA Style", "Minecraft Style", "Valorant Style", "Cyberpunk 2077", "Fortnite Style", "Elden Ring", "Pop Culture"]
        case .mood:
            return ["Rain on Window", "Fog", "Lonely Places", "Libraries", "Evening Lights", "Solitude & Peace"]
        case .lofi:
            return ["Lo-fi Girl Inspired", "Chill Environment", "Study & Work", "Relaxing Scenes", "Warm Colors", "Cozy Rooms"]
        case .animals:
            return ["Cats", "Dogs", "Foxes", "Pandas", "Bears", "Minimalist Animals", "Fantasy Animals"]
        case .tech:
            return ["Abstract Tech Design", "Glitch Art", "Holograms", "Digital Network", "Sci-fi Cities", "Matrix Style"]
        case .quotes:
            return ["Self-confidence", "Productivity", "Peace & Calm", "Typography Quotes", "Aesthetic Quotes", "Growth & Change"]
        case .colors:
            return ["Pastel", "Monochrome", "Sunset Tones", "Blue Vibes", "Earth Tones", "Dark Mode", "Duotone"]
        case .seasonal:
            return ["Spring", "Summer", "Autumn", "Winter", "Halloween", "Christmas", "New Year", "Back to School", "Cozy Season"]
        case .threeD:
            return ["Optical Illusions", "Pseudo-3D Space", "Depth Wallpapers", "Layered Scenes", "3D Light Effects"]
        }
    }
}
