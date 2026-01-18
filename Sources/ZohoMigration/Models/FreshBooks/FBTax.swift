import Foundation

struct FBTaxResponse: Codable {
    let response: FBTaxResponseBody
}

struct FBTaxResponseBody: Codable {
    let result: FBTaxResult
}

struct FBTaxResult: Codable {
    let taxes: [FBTax]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case taxes
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}

struct FBTax: Codable, Identifiable {
    let id: Int
    let accountingSystemId: String?
    let name: String?
    let amount: String?
    let number: String?
    let taxId: Int?
    let updated: String?
    let compound: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case accountingSystemId = "accounting_systemid"
        case name
        case amount
        case number
        case taxId = "taxid"
        case updated
        case compound
    }

    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return "Tax \(id)"
    }

    var percentage: Double? {
        guard let amount = amount else { return nil }
        return Double(amount)
    }
}
