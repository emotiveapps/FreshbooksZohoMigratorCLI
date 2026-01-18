import Foundation

struct FBItemResponse: Codable {
    let response: FBItemResponseBody
}

struct FBItemResponseBody: Codable {
    let result: FBItemResult
}

struct FBItemResult: Codable {
    let items: [FBItem]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case items
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}

struct FBItem: Codable, Identifiable {
    let id: Int
    let accountingSystemId: String?
    let name: String?
    let description: String?
    let qty: String?
    let sku: String?
    let inventory: String?
    let unitCost: FBMoney?
    let tax1: Int?
    let tax2: Int?
    let visState: Int?
    let updated: String?

    enum CodingKeys: String, CodingKey {
        case id
        case accountingSystemId = "accounting_systemid"
        case name
        case description
        case qty
        case sku
        case inventory
        case unitCost = "unit_cost"
        case tax1
        case tax2
        case visState = "vis_state"
        case updated
    }

    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return "Item \(id)"
    }
}
