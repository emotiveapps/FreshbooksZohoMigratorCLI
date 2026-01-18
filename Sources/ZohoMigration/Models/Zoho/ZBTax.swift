import Foundation

struct ZBTaxResponse: Codable {
    let code: Int
    let message: String
    let tax: ZBTax?
}

struct ZBTaxListResponse: Codable {
    let code: Int
    let message: String
    let taxes: [ZBTax]?
}

struct ZBTax: Codable {
    var taxId: String?
    var taxName: String
    var taxPercentage: Double?
    var taxType: String?
    var taxSpecificType: String?
    var isValueAdded: Bool?
    var isDefaultTax: Bool?
    var isEditable: Bool?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case taxId = "tax_id"
        case taxName = "tax_name"
        case taxPercentage = "tax_percentage"
        case taxType = "tax_type"
        case taxSpecificType = "tax_specific_type"
        case isValueAdded = "is_value_added"
        case isDefaultTax = "is_default_tax"
        case isEditable = "is_editable"
        case status
    }
}

struct ZBTaxCreateRequest: Codable {
    var taxName: String
    var taxPercentage: Double
    var taxType: String?

    enum CodingKeys: String, CodingKey {
        case taxName = "tax_name"
        case taxPercentage = "tax_percentage"
        case taxType = "tax_type"
    }
}
