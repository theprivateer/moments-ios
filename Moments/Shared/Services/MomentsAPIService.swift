import Foundation
import UIKit

struct MomentsAPIService {
    func uploadImage(_ image: UIImage, serverURL: String, token: String) async throws -> MomentImage {
        guard let url = URL(string: "\(serverURL)/api/v1/images") else {
            throw AppError.serverError(statusCode: 0, message: "Invalid server URL")
        }

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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw AppError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.serverError(statusCode: 0, message: "Invalid response")
        }

        switch httpResponse.statusCode {
        case 201:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                let imageResponse = try decoder.decode(MomentImageResponse.self, from: data)
                return imageResponse.data
            } catch {
                throw AppError.decodingError(error)
            }
        case 401:
            throw AppError.unauthorized
        case 422:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let json = try? decoder.decode([String: [String: [String]]].self, from: data),
               let errors = json["errors"] {
                throw AppError.validationError(errors)
            }
            throw AppError.serverError(statusCode: 422, message: "Validation failed")
        default:
            let message = String(data: data, encoding: .utf8)
            throw AppError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    func fetchTimeline(page: Int = 1, serverURL: String, token: String) async throws -> MomentListResponse {
        var components = URLComponents(string: "\(serverURL)/api/v1/moments")
        components?.queryItems = [URLQueryItem(name: "page", value: String(page))]
        guard let url = components?.url else {
            throw AppError.serverError(statusCode: 0, message: "Invalid server URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw AppError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.serverError(statusCode: 0, message: "Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                return try decoder.decode(MomentListResponse.self, from: data)
            } catch {
                throw AppError.decodingError(error)
            }
        case 401:
            throw AppError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8)
            throw AppError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    func postMoment(body: String?, imageIDs: [Int], serverURL: String, token: String) async throws -> Moment {
        guard let url = URL(string: "\(serverURL)/api/v1/moments") else {
            throw AppError.serverError(statusCode: 0, message: "Invalid server URL")
        }

        var payload: [String: Any] = ["images": imageIDs]
        if let body { payload["body"] = body }
        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw AppError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.serverError(statusCode: 0, message: "Invalid response")
        }

        switch httpResponse.statusCode {
        case 201:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                let momentResponse = try decoder.decode(MomentResponse.self, from: data)
                return momentResponse.data
            } catch {
                throw AppError.decodingError(error)
            }
        case 401:
            throw AppError.unauthorized
        case 422:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let json = try? decoder.decode([String: [String: [String]]].self, from: data),
               let errors = json["errors"] {
                throw AppError.validationError(errors)
            }
            throw AppError.serverError(statusCode: 422, message: "Validation failed")
        default:
            let message = String(data: data, encoding: .utf8)
            throw AppError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}
