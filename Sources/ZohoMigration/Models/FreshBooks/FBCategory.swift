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

struct FBCategory: Codable, Identifiable, Equatable {
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

    /// Key for deduplication: name + parentId
    var deduplicationKey: String {
        "\(name)|\(parentId ?? -1)"
    }

    /// Compare two categories (excluding id) and return list of differences
    func differences(from other: FBCategory) -> [String] {
        var diffs: [String] = []

        if categoryId != other.categoryId {
            diffs.append("categoryId: \(categoryId ?? 0) vs \(other.categoryId ?? 0)")
        }
        if category != other.category {
            diffs.append("category: '\(category ?? "nil")' vs '\(other.category ?? "nil")'")
        }
        if createdAt != other.createdAt {
            diffs.append("createdAt: \(createdAt ?? "nil") vs \(other.createdAt ?? "nil")")
        }
        if isEditable != other.isEditable {
            diffs.append("isEditable: \(isEditable ?? false) vs \(other.isEditable ?? false)")
        }
        if isCogs != other.isCogs {
            diffs.append("isCogs: \(isCogs ?? false) vs \(other.isCogs ?? false)")
        }
        if parentId != other.parentId {
            diffs.append("parentId: \(parentId ?? 0) vs \(other.parentId ?? 0)")
        }
        if visState != other.visState {
            diffs.append("visState: \(visState ?? 0) vs \(other.visState ?? 0)")
        }

        return diffs
    }

    /// Check if two categories are equivalent (same values except id)
    func isEquivalent(to other: FBCategory) -> Bool {
        return differences(from: other).isEmpty
    }
}
