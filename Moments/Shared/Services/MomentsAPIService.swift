import Foundation
import UIKit

private enum MomentsEndpoint {
    case uploadImage
    case fetchTimeline(page: Int)
    case postMoment
    case patchMoment(id: Int)
    case deleteMoment(id: Int)

    var path: String {
        switch self {
        case .uploadImage:        return "/api/v1/images"
        case .fetchTimeline:      return "/api/v1/moments"
        case .postMoment:         return "/api/v1/moments"
        case .patchMoment(let id):  return "/api/v1/moments/\(id)"
        case .deleteMoment(let id): return "/api/v1/moments/\(id)"
        }
    }

    var method: String {
        switch self {
        case .uploadImage:   return "POST"
        case .fetchTimeline: return "GET"
        case .postMoment:    return "POST"
        case .patchMoment:   return "PATCH"
        case .deleteMoment:  return "DELETE"
        }
    }

    func urlRequest(baseURL: String, token: String) throws -> URLRequest {
        let url: URL
        if case .fetchTimeline(let page) = self {
            var components = URLComponents(string: "\(baseURL)\(path)")
            components?.queryItems = [URLQueryItem(name: "page", value: String(page))]
            guard let resolved = components?.url else {
                throw AppError.serverError(statusCode: 0, message: "Invalid server URL")
            }
            url = resolved
        } else {
            guard let resolved = URL(string: "\(baseURL)\(path)") else {
                throw AppError.serverError(statusCode: 0, message: "Invalid server URL")
            }
            url = resolved
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}

private let sharedDecoder: JSONDecoder = {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    return d
}()

struct MomentsAPIService {
    func uploadImage(_ image: UIImage, serverURL: String, token: String) async throws -> MomentImage {
        var request = try MomentsEndpoint.uploadImage.urlRequest(baseURL: serverURL, token: token)

        let boundary = "Boundary-\(UUID().uuidString)"
        let crlf = "\r\n"
        var body = Data()
        func append(_ string: String) {
            if let encoded = string.data(using: .utf8) { body.append(encoded) }
        }
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw AppError.serverError(statusCode: 0, message: "Failed to encode image")
        }
        append("--\(boundary)\(crlf)")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\(crlf)")
        append("Content-Type: image/jpeg\(crlf)\(crlf)")
        body.append(imageData)
        append(crlf)
        append("--\(boundary)--\(crlf)")

        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await perform(request)
        switch response.statusCode {
        case 200...299:
            return try decode(MomentImageResponse.self, from: data).data
        case 401:
            throw AppError.unauthorized
        case 422:
            throw validationError(from: data, fallbackCode: 422)
        default:
            throw AppError.serverError(statusCode: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }

    func fetchTimeline(page: Int = 1, serverURL: String, token: String) async throws -> MomentListResponse {
        let request = try MomentsEndpoint.fetchTimeline(page: page).urlRequest(baseURL: serverURL, token: token)
        let (data, response) = try await perform(request)
        switch response.statusCode {
        case 200...299:
            return try decode(MomentListResponse.self, from: data)
        case 401:
            throw AppError.unauthorized
        default:
            throw AppError.serverError(statusCode: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }

    func patchMoment(id: Int, body: String?, addImageIDs: [Int], removeImageIDs: [Int], serverURL: String, token: String) async throws -> Moment {
        var request = try MomentsEndpoint.patchMoment(id: id).urlRequest(baseURL: serverURL, token: token)

        var payload: [String: Any] = [:]
        if let body { payload["body"] = body }
        if !addImageIDs.isEmpty { payload["add_images"] = addImageIDs }
        if !removeImageIDs.isEmpty { payload["remove_images"] = removeImageIDs }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await perform(request)
        switch response.statusCode {
        case 200...299:
            return try decode(MomentResponse.self, from: data).data
        case 401:
            throw AppError.unauthorized
        case 422:
            throw validationError(from: data, fallbackCode: 422)
        default:
            throw AppError.serverError(statusCode: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }

    func deleteMoment(id: Int, serverURL: String, token: String) async throws {
        let request = try MomentsEndpoint.deleteMoment(id: id).urlRequest(baseURL: serverURL, token: token)
        let (data, response) = try await perform(request)
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw AppError.unauthorized
        default:
            throw AppError.serverError(statusCode: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }

    func postMoment(body: String?, imageIDs: [Int], serverURL: String, token: String) async throws -> Moment {
        var request = try MomentsEndpoint.postMoment.urlRequest(baseURL: serverURL, token: token)

        var payload: [String: Any] = ["images": imageIDs]
        if let body { payload["body"] = body }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await perform(request)
        switch response.statusCode {
        case 200...299:
            return try decode(MomentResponse.self, from: data).data
        case 401:
            throw AppError.unauthorized
        case 422:
            throw validationError(from: data, fallbackCode: 422)
        default:
            throw AppError.serverError(statusCode: response.statusCode, message: String(data: data, encoding: .utf8))
        }
    }

    // MARK: - Helpers

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw AppError.networkError(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AppError.serverError(statusCode: 0, message: "Invalid response")
        }
        return (data, http)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try sharedDecoder.decode(type, from: data)
        } catch {
            throw AppError.decodingError(error)
        }
    }

    private func validationError(from data: Data, fallbackCode: Int) -> AppError {
        if let json = try? sharedDecoder.decode([String: [String: [String]]].self, from: data),
           let errors = json["errors"] {
            return AppError.validationError(errors)
        }
        return AppError.serverError(statusCode: fallbackCode, message: "Validation failed")
    }
}
