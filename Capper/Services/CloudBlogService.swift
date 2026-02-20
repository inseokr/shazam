//
//  CloudBlogService.swift
//  Capper
//
//  Thin REST client for all cloud blog operations.
//  Wraps APIManager and maps server JSON to local CloudBlog structs.
//

import Foundation

// MARK: - CloudBlog (server-side model)

/// Lightweight server representation of a blog. Only contains fields
/// the server returns; full blog detail lives in RecapBlogDetail locally.
struct CloudBlog: Codable, Sendable {
    let id: String           // MongoDB _id
    let title: String
    let coverImageName: String?
    let countryName: String?
    let tripDateRangeText: String?
    let createdAt: Date?
    let updatedAt: Date?
    let isArchived: Bool
    let shareSlug: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case coverImageName
        case countryName
        case tripDateRangeText
        case createdAt
        case updatedAt
        case isArchived
        case shareSlug
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(String.self, forKey: .id)
        title           = try c.decode(String.self, forKey: .title)
        coverImageName  = try c.decodeIfPresent(String.self, forKey: .coverImageName)
        countryName     = try c.decodeIfPresent(String.self, forKey: .countryName)
        tripDateRangeText = try c.decodeIfPresent(String.self, forKey: .tripDateRangeText)
        createdAt       = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt       = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        isArchived      = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        shareSlug       = try c.decodeIfPresent(String.self, forKey: .shareSlug)
    }
}

// MARK: - Payloads

struct CloudBlogCreatePayload: Encodable {
    let title: String
    let coverImageName: String?
    let countryName: String?
    let tripDateRangeText: String?
}

struct CloudBlogStatusPayload: Encodable {
    let status: String   // "active" or "archived"
}

// MARK: - Response wrappers

private struct CloudBlogListResponse: Decodable {
    let blogs: [CloudBlog]?
    let result: String?
}

private struct CloudBlogSingleResponse: Decodable {
    let blog: CloudBlog?
    let result: String?
}

private struct PublishBlogResponse: Decodable {
    let shareSlug: String?
    let result: String?
}

// MARK: - Error

enum CloudBlogError: LocalizedError {
    case limitReached
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .limitReached:
            return "You've reached the free tier limit of 5 active cloud blogs. Upgrade to Pro for unlimited blogs."
        case .serverError(let msg):
            return "Server error: \(msg)"
        }
    }
}

// MARK: - CloudBlogService

final class CloudBlogService {
    static let shared = CloudBlogService()
    private init() {}

    // MARK: - Fetch

    /// GET /bloggo/blogs — returns all cloud blogs for the authenticated user.
    func fetchBlogs() async throws -> [CloudBlog] {
        let response: CloudBlogListResponse = try await APIManager.shared.get(
            endpoint: "/bloggo/blogs",
            requiresAuth: true
        )
        return response.blogs ?? []
    }

    // MARK: - Create

    /// POST /bloggo/blogs — creates a new cloud blog entry (without photos).
    func createBlog(_ payload: CloudBlogCreatePayload) async throws -> CloudBlog {
        let response: CloudBlogSingleResponse = try await APIManager.shared.post(
            endpoint: "/bloggo/blogs",
            body: payload,
            requiresAuth: true
        )
        guard let blog = response.blog else {
            throw CloudBlogError.serverError("No blog returned from create.")
        }
        return blog
    }

    // MARK: - Update

    /// PUT /bloggo/blogs/:id — updates blog metadata.
    func updateBlog(id: String, payload: CloudBlogCreatePayload) async throws {
        let _: CloudBlogSingleResponse = try await APIManager.shared.request(
            endpoint: "/bloggo/blogs/\(id)",
            method: "PUT",
            body: try JSONEncoder().encode(payload),
            requiresAuth: true
        )
    }

    // MARK: - Archive / Restore

    /// PATCH /bloggo/blogs/:id/status — sets blog to "active" or "archived".
    func setBlogStatus(id: String, active: Bool) async throws {
        let body = CloudBlogStatusPayload(status: active ? "active" : "archived")
        let _: CloudBlogSingleResponse = try await APIManager.shared.request(
            endpoint: "/bloggo/blogs/\(id)/status",
            method: "PATCH",
            body: try JSONEncoder().encode(body),
            requiresAuth: true
        )
    }

    // MARK: - Publish

    /// POST /bloggo/blogs/:id/publish — generates a shareSlug for the blog.
    /// - Returns: The public shareSlug string.
    /// - Throws: `CloudBlogError.limitReached` when the free tier (5 active blogs) is exceeded.
    func publishBlog(id: String) async throws -> String {
        do {
            let response: PublishBlogResponse = try await APIManager.shared.request(
                endpoint: "/bloggo/blogs/\(id)/publish",
                method: "POST",
                requiresAuth: true
            )
            guard let slug = response.shareSlug else {
                throw CloudBlogError.serverError("No shareSlug returned.")
            }
            return slug
        } catch APIError.httpError(let statusCode, let message) {
            if statusCode == 403 {
                throw CloudBlogError.limitReached
            }
            throw CloudBlogError.serverError(message)
        }
    }
}
