import Foundation

struct ZBItemResponse: Codable {
    let code: Int
    let message: String
    let item: ZBItem?
}

struct ZBItemListResponse: Codable {
    let code: Int
    let message: String
    let items: [ZBItem]?
}

struct ZBItem: Codable {
    var itemId: String?
    var name: String
    var description: String?
    var rate: Double?
    var unit: String?
    var sku: String?
    var taxId: String?
    var taxName: String?
    var taxPercentage: Double?
    var taxType: String?
    var productType: String?
    var isReturnable: Bool?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case name
        case description
        case rate
        case unit
        case sku
        case taxId = "tax_id"
        case taxName = "tax_name"
        case taxPercentage = "tax_percentage"
        case taxType = "tax_type"
        case productType = "product_type"
        case isReturnable = "is_returnable"
        case status
    }
}

struct ZBItemCreateRequest: Codable {
    var name: String
    var description: String?
    var rate: Double?
    var unit: String?
    var sku: String?
    var taxId: String?
    var productType: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case rate
        case unit
        case sku
        case taxId = "tax_id"
        case productType = "product_type"
    }
}
