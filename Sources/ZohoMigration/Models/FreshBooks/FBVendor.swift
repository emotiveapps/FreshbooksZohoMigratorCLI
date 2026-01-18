import Foundation

struct FBVendorResponse: Codable {
    let response: FBVendorResponseBody
}

struct FBVendorResponseBody: Codable {
    let result: FBVendorResult
}

struct FBVendorResult: Codable {
    let billVendors: [FBVendor]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case billVendors = "bill_vendors"
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}

struct FBVendor: Codable, Identifiable {
    let id: Int
    let accountId: String?
    let accountNumber: String?
    let city: String?
    let country: String?
    let currencyCode: String?
    let is1099: Bool?
    let language: String?
    let note: String?
    let outstandingBalance: [FBOutstandingBalance]?
    let phone: String?
    let postalCode: String?
    let primaryContactEmail: String?
    let primaryContactFirstName: String?
    let primaryContactLastName: String?
    let province: String?
    let street: String?
    let street2: String?
    let taxId: String?
    let vendorName: String?
    let visState: Int?
    let website: String?

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case accountNumber = "account_number"
        case city
        case country
        case currencyCode = "currency_code"
        case is1099 = "is_1099"
        case language
        case note
        case outstandingBalance = "outstanding_balance"
        case phone
        case postalCode = "postal_code"
        case primaryContactEmail = "primary_contact_email"
        case primaryContactFirstName = "primary_contact_first_name"
        case primaryContactLastName = "primary_contact_last_name"
        case province
        case street
        case street2
        case taxId = "tax_id"
        case vendorName = "vendor_name"
        case visState = "vis_state"
        case website
    }

    var displayName: String {
        vendorName ?? "\(primaryContactFirstName ?? "") \(primaryContactLastName ?? "")".trimmingCharacters(in: .whitespaces)
    }
}

struct FBOutstandingBalance: Codable {
    let amount: FBAmount?
    let code: String?
}

struct FBAmount: Codable {
    let amount: String?
    let code: String?
}
