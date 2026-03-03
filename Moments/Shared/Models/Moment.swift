import Foundation

struct MomentResponse: Decodable, Sendable {
    let data: Moment
}

struct Moment: Codable, Identifiable, Sendable {
    let id: Int
    let body: String?
    let bodyHTML: String?
    let createdAt: String
    let images: [MomentImage]

    enum CodingKeys: String, CodingKey {
        case id
        case body
        case bodyHTML = "bodyHtml"
        case createdAt
        case images
    }
}

struct MomentImage: Codable, Identifiable, Sendable {
    let id: Int
    let url: String
}

struct MomentImageResponse: Decodable, Sendable {
    let data: MomentImage
}

struct MomentListResponse: Decodable, Sendable {
    let data: [Moment]
    let links: MomentListLinks
    let meta: MomentListMeta
}

struct MomentListLinks: Decodable, Sendable {
    let first, last, prev, next: String?
}

struct MomentListMeta: Decodable, Sendable {
    let currentPage, lastPage, perPage, total: Int
    let from, to: Int?
    let path: String
}
