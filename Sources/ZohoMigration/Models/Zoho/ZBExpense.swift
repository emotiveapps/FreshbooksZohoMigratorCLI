import Foundation

struct ZBExpenseResponse: Codable {
    let code: Int
    let message: String
    let expense: ZBExpense?
}

struct ZBExpenseListResponse: Codable {
    let code: Int
    let message: String
    let expenses: [ZBExpense]?
    let pageContext: ZBPageContext?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case expenses
        case pageContext = "page_context"
    }
}

struct ZBExpense: Codable {
    var expenseId: String?
    var accountId: String?
    var accountName: String?
    var paidThroughAccountId: String?
    var paidThroughAccountName: String?
    var vendorId: String?
    var vendorName: String?
    var date: String?
    var amount: Double?
    var taxId: String?
    var taxName: String?
    var taxPercentage: Double?
    var taxAmount: Double?
    var subTotal: Double?
    var total: Double?
    var isBillable: Bool?
    var customerId: String?
    var customerName: String?
    var projectId: String?
    var projectName: String?
    var currencyId: String?
    var currencyCode: String?
    var referenceNumber: String?
    var description: String?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case expenseId = "expense_id"
        case accountId = "account_id"
        case accountName = "account_name"
        case paidThroughAccountId = "paid_through_account_id"
        case paidThroughAccountName = "paid_through_account_name"
        case vendorId = "vendor_id"
        case vendorName = "vendor_name"
        case date
        case amount
        case taxId = "tax_id"
        case taxName = "tax_name"
        case taxPercentage = "tax_percentage"
        case taxAmount = "tax_amount"
        case subTotal = "sub_total"
        case total
        case isBillable = "is_billable"
        case customerId = "customer_id"
        case customerName = "customer_name"
        case projectId = "project_id"
        case projectName = "project_name"
        case currencyId = "currency_id"
        case currencyCode = "currency_code"
        case referenceNumber = "reference_number"
        case description
        case status
    }
}

struct ZBExpenseCreateRequest: Codable {
    var accountId: String
    var paidThroughAccountId: String?
    var vendorId: String?
    var date: String
    var amount: Double
    var taxId: String?
    var isBillable: Bool?
    var customerId: String?
    var projectId: String?
    var currencyCode: String?
    var referenceNumber: String?
    var description: String?
    var tags: [ZBTag]?

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case paidThroughAccountId = "paid_through_account_id"
        case vendorId = "vendor_id"
        case date
        case amount
        case taxId = "tax_id"
        case isBillable = "is_billable"
        case customerId = "customer_id"
        case projectId = "project_id"
        case currencyCode = "currency_code"
        case referenceNumber = "reference_number"
        case description
        case tags
    }
}

/// Zoho Books tag for tracking categories
struct ZBTag: Codable {
    var tagId: String
    var tagOptionId: String

    enum CodingKeys: String, CodingKey {
        case tagId = "tag_id"
        case tagOptionId = "tag_option_id"
    }
}
