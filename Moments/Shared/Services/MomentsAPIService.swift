import Foundation
import UIKit

struct MomentsAPIService {
    func postMoment(body: String?, images: [UIImage], serverURL: String, token: String) async throws -> Moment {
        guard let url = URL(string: "\(serverURL)/api/v1/moments") else {
            throw AppError.serverError(statusCode: 0, message: "Invalid server URL")
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildMultipartBody(body: body, images: images, boundary: boundary)

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

    private func buildMultipartBody(body: String?, images: [UIImage], boundary: String) -> Data {
        var data = Data()
        let crlf = "\r\n"

        func append(_ string: String) {
            if let encoded = string.data(using: .utf8) {
                data.append(encoded)
            }
        }

        if let body {
            append("--\(boundary)\(crlf)")
            append("Content-Disposition: form-data; name=\"body\"\(crlf)\(crlf)")
            append(body)
            append(crlf)
        }

        for image in images {
            guard let imageData = image.jpegData(compressionQuality: 0.85) else { continue }
            append("--\(boundary)\(crlf)")
            append("Content-Disposition: form-data; name=\"images[]\"; filename=\"image.jpg\"\(crlf)")
            append("Content-Type: image/jpeg\(crlf)\(crlf)")
            data.append(imageData)
            append(crlf)
        }

        append("--\(boundary)--\(crlf)")
        return data
    }
}
