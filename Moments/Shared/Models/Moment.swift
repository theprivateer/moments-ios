import Foundation

struct MomentResponse: Decodable, Sendable {
    let data: Moment
}

struct Moment: Decodable, Sendable {
    let id: Int
    let body: String?
    let bodyHTML: String?
    let createdAt: String
    let images: [MomentImage]
}

struct MomentImage: Decodable, Sendable {
    let id: Int
    let url: String
}

struct MomentImageResponse: Decodable, Sendable {
    let data: MomentImage
}
