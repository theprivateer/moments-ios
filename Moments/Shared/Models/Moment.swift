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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        bodyHTML = try container.decodeIfPresent(String.self, forKey: .bodyHTML)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        images = try container.decode([MomentImage].self, forKey: .images)
            .sorted { lhs, rhs in
                if lhs.position == rhs.position {
                    return lhs.id < rhs.id
                }
                return lhs.position < rhs.position
            }
    }
}

struct MomentImage: Codable, Identifiable, Sendable {
    let id: Int
    let url: String
    let position: Int
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
