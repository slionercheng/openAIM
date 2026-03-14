//
//  APIClient.swift
//  openAIM
//
//  Created by Claude on 2026/3/7.
//

import Foundation

/// API 错误类型
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case unauthorized
    case networkError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let statusCode, let message):
            return message ?? "HTTP 错误: \(statusCode)"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .encodingError(let error):
            return "数据编码错误: \(error.localizedDescription)"
        case .unauthorized:
            return "未授权，请重新登录"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .unknown:
            return "未知错误"
        }
    }
}

/// API 响应包装
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let message: String?
    let data: T
}

/// API 客户端 - 支持 Multi-Instance
/// 重要：Token 从 SessionManager 获取，每个实例有独立的会话
class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// 获取当前访问令牌（从 SessionManager 获取，实例独享）
    private var accessToken: String? {
        // 从 SessionManager 获取 token（内存中，实例独享）
        // 不再使用 Keychain，避免多实例共享问题
        return SessionManager.shared.accessToken
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.requestTimeout
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // 自定义日期解码策略，支持带微秒的 ISO8601 格式
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // 尝试 ISO8601DateFormatter（支持带分数秒的格式）
            let iso8601WithFractional = ISO8601DateFormatter()
            iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let iso8601Basic = ISO8601DateFormatter()
            iso8601Basic.formatOptions = [.withInternetDateTime]

            if let date = iso8601WithFractional.date(from: dateString) {
                return date
            }
            if let date = iso8601Basic.date(from: dateString) {
                return date
            }

            // 使用 DateFormatter 处理带微秒的格式
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            // 尝试多种格式
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSZZZZZ",
                "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
                "yyyy-MM-dd'T'HH:mm:ssZ"
            ]

            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }

        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Public Methods

    /// GET 请求
    func get<T: Codable>(_ endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        guard var components = URLComponents(string: Constants.baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return try await performRequest(request)
    }

    /// POST 请求
    func post<T: Codable, U: Encodable>(_ endpoint: String, body: U? = nil) async throws -> T {
        guard let url = URL(string: Constants.baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw APIError.encodingError(error)
            }
        }

        return try await performRequest(request)
    }

    /// POST 请求（无返回值）
    func post<U: Encodable>(_ endpoint: String, body: U? = nil) async throws {
        guard let url = URL(string: Constants.baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw APIError.encodingError(error)
            }
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }
    }

    /// PUT 请求
    func put<T: Codable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        guard let url = URL(string: Constants.baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw APIError.encodingError(error)
        }

        return try await performRequest(request)
    }

    /// DELETE 请求
    func delete(_ endpoint: String) async throws {
        guard let url = URL(string: Constants.baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }
    }

    // MARK: - Private Methods

    private func performRequest<T: Codable>(_ request: URLRequest) async throws -> T {
        logDebug("APIClient", "Request: \(request.url?.absoluteString ?? "nil")")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            logDebug("APIClient", "Response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                // 尝试解析错误消息
                if let errorResponse = try? decoder.decode(APIResponse<Empty>.self, from: data) {
                    throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorResponse.message)
                }
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
            }

            // 直接解码返回数据
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                logDebug("APIClient", "Direct decode failed: \(error)")
                // 尝试解码包装后的响应
                do {
                    let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
                    return apiResponse.data
                } catch let wrapperError {
                    logDebug("APIClient", "Wrapper decode also failed: \(wrapperError)")
                }
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}

/// 空类型用于解码空响应
struct Empty: Codable {}