import Foundation

struct FBCategoryResponse: Codable {
    let response: FBCategoryResponseBody
}

struct FBCategoryResponseBody: Codable {
    let result: FBCategoryResult
}

struct FBCategoryResult: Codable {
    let categories: [FBCategory]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case categories
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}

struct FBCategory: Codable, Identifiable {
    let id: Int
    let categoryId: Int?
    let category: String?
    let createdAt: String?
    let isEditable: Bool?
    let isCogs: Bool?
    let parentId: Int?
    let visState: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "categoryid"
        case category
        case createdAt = "created_at"
        case isEditable = "is_editable"
        case isCogs = "is_cogs"
        case parentId = "parentid"
        case visState = "vis_state"
    }

    var name: String {
        category ?? "Unknown Category"
    }
}
