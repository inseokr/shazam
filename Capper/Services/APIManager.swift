//
//  APIManager.swift
//  Capper
//
//  Centralized network manager that handles API requests, JSON encoding/decoding,
//  and automatically injects the JWT token into the Authorization header.
//

import Foundation
import UIKit

enum APIError: LocalizedError {
    case invalidURL
    case serializationFailed
    case networkError(Error)
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL configuration."
        case .serializationFailed: return "Failed to serialize the request body."
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .invalidResponse: return "Received an invalid response from the server."
        case .httpError(let statusCode, let message): return "HTTP Error \(statusCode): \(message)"
        case .decodingFailed(let error): return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

final class APIManager {
    static let shared = APIManager()
    
    // Actual API server URLs
    let baseURL = "https://pocketverse.herokuapp.com/LS_API"
    let fileServerURL = "https://ls-file-server-4312402ca23f.herokuapp.com/LS_FS_API"    
    private init() {}
    
    // MARK: - Generic Request Method
    
    /// Performs an authenticated or unauthenticated HTTP request
    /// - Parameters:
    ///   - endpoint: The API endpoint (e.g., "/jwt_login").
    ///   - method: HTTP method ("GET", "POST", etc.).
    ///   - body: Optional body data. Recommended to use `post<T, U>` for typed requests.
    ///   - requiresAuth: If true, injects the Bearer token. If true and no token is found, standard failure applies.
    /// - Returns: Decoded object of type `T`.
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Inject JWT Token (matching Axios Interceptor logic)
        if requiresAuth, let token = AuthService.shared.currentJwtToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Attempt to extract an error message from the response body
            var errorMessage = "Unknown server error."
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🚨 API Error Data JSON: \(json)")
                if let msg = json["message"] as? String {
                    errorMessage = msg
                } else if let err = json["error"] as? String {
                    errorMessage = err
                } else if let result = json["result"] as? String {
                    errorMessage = result
                }
            } else if let stringError = String(data: data, encoding: .utf8) {
                print("🚨 API Error Data String: \(stringError)")
                errorMessage = stringError
            }
            
            print("🚨 HTTP Error \(httpResponse.statusCode): \(errorMessage)")
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Performs a POST request with an Encodable body
    func post<T: Decodable, U: Encodable>(endpoint: String, body: U, requiresAuth: Bool = true) async throws -> T {
        let requestData = try JSONEncoder().encode(body)
        return try await request(endpoint: endpoint, method: "POST", body: requestData, requiresAuth: requiresAuth)
    }
    
    /// Performs a GET request
    func get<T: Decodable>(endpoint: String, requiresAuth: Bool = true) async throws -> T {
        return try await request(endpoint: endpoint, method: "GET", body: nil, requiresAuth: requiresAuth)
    }

    // MARK: - File Server Upload

    /// Uploads a UIImage to the file server as a compressed JPEG.
    /// - Parameters:
    ///   - image: The UIImage to upload.
    ///   - filename: Filename for the upload (default: "photo.jpg").
    /// - Returns: The cloud URL string from the server response.
    func uploadPhoto(image: UIImage, filename: String = "photo.jpg") async throws -> String {
        guard let url = URL(string: fileServerURL + "/place/file_upload") else {
            throw APIError.invalidURL
        }

        // Compress to JPEG at 0.2 quality (matches LinkedSpaces compress: 0.2)
        guard let imageData = image.jpegData(compressionQuality: 0.2) else {
            throw APIError.serializationFailed
        }

        // Build multipart/form-data body — field name MUST be "photo"
        let boundary = UUID().uuidString
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"photo\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(imageData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Let the boundary be set explicitly — do NOT set a bare "multipart/form-data"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Inject JWT token
        if let token = AuthService.shared.currentJwtToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            var errorMessage = "Upload failed."
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🚨 Upload Error JSON: \(json)")
                errorMessage = (json["message"] as? String)
                    ?? (json["error"] as? String)
                    ?? errorMessage
            }
            print("🚨 Upload HTTP Error \(httpResponse.statusCode): \(errorMessage)")
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Server returns { "path": "https://...cloud-url..." }
        struct FileUploadResponse: Decodable {
            let path: String?
        }

        let result: FileUploadResponse
        do {
            result = try JSONDecoder().decode(FileUploadResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }

        guard let cloudURL = result.path, !cloudURL.isEmpty else {
            throw APIError.invalidResponse
        }

        return cloudURL
    }

    /// Convenience: uploads a photo from the iOS Photos library by asset identifier.
    /// Loads the image at up to 1920×1920, compresses, and uploads.
    func uploadPhoto(assetIdentifier: String) async throws -> String {
        let image = await ImageLoader.shared.loadImage(
            assetIdentifier: assetIdentifier,
            targetSize: CGSize(width: 1920, height: 1920)
        )
        guard let image else {
            throw APIError.serializationFailed
        }
        let filename = "IMG_\(assetIdentifier.prefix(8)).jpg"
        return try await uploadPhoto(image: image, filename: filename)
    }

    // MARK: - Blog Publishing

    /// Publishes a RecapBlogDetail JSON to the API server so it can be viewed on the web.
    /// Called after photos are uploaded to the cloud (fire-and-forget from the UI).
    func publishBlogDetail(_ detail: RecapBlogDetail) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(detail)
        let _: PublishResponse = try await request(
            endpoint: "/bloggo/recap/publish",
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }
}

private struct PublishResponse: Decodable {
    let result: String?
}
