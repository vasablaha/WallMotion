//
//  NetworkManager.swift
//  WallMotion
//
//  Network communication manager for API calls
//

import Foundation
import Combine

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let baseURL = "https://wallmotion.eu/api" // Updated to new domain
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Generic Request Method
    
    private func performRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        print("🌐 Making \(method.rawValue) request to: \(url)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            // Log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response body: \(responseString)")
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                // Try to parse error message
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw NetworkError.serverError(errorResponse.error)
                } else {
                    throw NetworkError.httpError(httpResponse.statusCode)
                }
            }
            
            let decoder = JSONDecoder()
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
                }
            }
            
            return try decoder.decode(responseType, from: data)
            
        } catch {
            print("❌ Network error: \(error)")
            throw error
        }
    }
    
    func logoutDevice(fingerprint: String, authToken: String) async throws -> LogoutResponse {
        guard let url = URL(string: "\(baseURL)/api/devices") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let body = [
            "fingerprint": fingerprint,
            "action": "logout"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let logoutResponse = try JSONDecoder().decode(LogoutResponse.self, from: data)
            return logoutResponse
        } else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NetworkError.serverError(errorResponse?.error ?? "Unknown error")
        }
    }
    
    
    // MARK: - Authentication Methods
    
    func validateLicense(fingerprint: String, bundleId: String, version: String) async throws -> LicenseValidationResponse {
        let request = LicenseValidationRequest(
            fingerprint: fingerprint,
            bundleId: bundleId,
            version: version
        )
        
        let body = try JSONEncoder().encode(request)
        
        return try await performRequest(
            endpoint: "/validate-license",
            method: .POST,
            body: body,
            responseType: LicenseValidationResponse.self
        )
    }
    
    func registerDevice(
        fingerprint: String,
        name: String,
        macModel: String?,
        macosVersion: String?,
        appVersion: String?,
        authToken: String
    ) async throws -> DeviceRegistrationResponse {
        let request = DeviceRegistrationRequest(
            fingerprint: fingerprint,
            name: name,
            macModel: macModel,
            macosVersion: macosVersion,
            appVersion: appVersion
        )
        
        let body = try JSONEncoder().encode(request)
        let headers = ["Authorization": "Bearer \(authToken)"]
        
        return try await performRequest(
            endpoint: "/devices",
            method: .POST,
            body: body,
            headers: headers,
            responseType: DeviceRegistrationResponse.self
        )
    }
    
    func getDevices(authToken: String) async throws -> DevicesResponse {
        let headers = ["Authorization": "Bearer \(authToken)"]
        
        return try await performRequest(
            endpoint: "/devices",
            method: .GET,
            headers: headers,
            responseType: DevicesResponse.self
        )
    }
    
    func getUserInfo(authToken: String) async throws -> UserResponse {
        let headers = ["Authorization": "Bearer \(authToken)"]
        
        return try await performRequest(
            endpoint: "/users",
            method: .GET,
            headers: headers,
            responseType: UserResponse.self
        )
    }
}

// MARK: - HTTP Method Enum

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - Network Error Enum

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case decodingError
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .serverError(let message):
            return "Server Error: \(message)"
        case .decodingError:
            return "Failed to decode response"
        case .noData:
            return "No data received"
        }
    }
}

// MARK: - Request Models

struct LicenseValidationRequest: Codable {
    let fingerprint: String
    let bundleId: String
    let version: String
}

struct DeviceRegistrationRequest: Codable {
    let fingerprint: String
    let name: String
    let macModel: String?
    let macosVersion: String?
    let appVersion: String?
}

// MARK: - Response Models

struct ErrorResponse: Codable {
    let error: String
}

struct LicenseValidationResponse: Codable {
    let valid: Bool
    let reason: String?
    let license: LicenseInfo?
}

struct LicenseInfo: Codable {
    let type: String
    let purchaseDate: Date?
    let features: [String]
    let deviceInfo: DeviceInfo?
}



struct DeviceRegistrationResponse: Codable {
    let success: Bool
    let device: Device?
}

struct DevicesResponse: Codable {
    let devices: [Device]
}

struct Device: Codable, Identifiable {
    let id: String
    let fingerprint: String
    let name: String
    let deviceDisplayName: String?  // NOVÉ - vlastní název zařízení
    let registeredAt: Date
    let lastSeen: Date
    let isActive: Bool
    let macModel: String?
    let macosVersion: String?
    let appVersion: String?
    let cognitoId: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case fingerprint, name, deviceDisplayName, registeredAt, lastSeen, isActive
        case macModel, macosVersion, appVersion, cognitoId
    }
    
    // Helper computed property pro zobrazení názvu
    var displayName: String {
        return deviceDisplayName ?? name
    }
}

struct DeviceInfo: Codable {
    let name: String
    let deviceDisplayName: String?  // NOVÉ
    let registeredAt: Date
    
    // Helper computed property pro zobrazení názvu
    var displayName: String {
        return deviceDisplayName ?? name
    }
}

struct UserResponse: Codable {
    let user: User
}

struct User: Codable {
    let id: String
    let email: String
    let licenseType: String
    let purchaseDate: Date?
    let licensesCount: Int?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email, licenseType, purchaseDate, licensesCount, createdAt
    }
}

    struct LogoutResponse: Codable {
        let success: Bool
        let message: String?
    }
