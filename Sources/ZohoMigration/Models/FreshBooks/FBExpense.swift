import Foundation

struct FBExpenseResponse: Codable {
    let response: FBExpenseResponseBody
}

struct FBExpenseResponseBody: Codable {
    let result: FBExpenseResult
}

struct FBExpenseResult: Codable {
    let expenses: [FBExpense]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case expenses
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}

struct FBExpense: Codable, Identifiable {
    let id: Int
    let accountId: String?
    let accountName: String?
    let accountingSystemId: String?
    let amount: FBMoney?
    let attachmentId: Int?
    let authorName: String?
    let backgroundJobId: Int?
    let bankName: String?
    let billable: Bool?
    let categoryId: Int?
    let clientId: Int?
    let compoundedTax: Bool?
    let date: String?
    let expenseId: Int?
    let extInvoiceId: Int?
    let extSystemId: Int?
    let hasReceipt: Bool?
    let hasTaxFields: Bool?
    let includeReceipt: Bool?
    let invoiceId: Int?
    let isDuplicate: Bool?
    let markupPercent: String?
    let modernProjectId: Int?
    let notes: String?
    let profileId: Int?
    let projectId: Int?
    let staffId: Int?
    let status: Int?
    let taxAmount1: FBMoney?
    let taxAmount2: FBMoney?
    let taxName1: String?
    let taxName2: String?
    let taxPercent1: String?
    let taxPercent2: String?
    let transactionId: Int?
    let updated: String?
    let vendor: String?
    let vendorId: Int?
    let visState: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case accountName = "account_name"
        case accountingSystemId = "accounting_systemid"
        case amount
        case attachmentId = "attachment_id"
        case authorName = "author_name"
        case backgroundJobId = "background_jobid"
        case bankName = "bank_name"
        case billable
        case categoryId = "categoryid"
        case clientId = "clientid"
        case compoundedTax = "compounded_tax"
        case date
        case expenseId = "expenseid"
        case extInvoiceId = "ext_invoiceid"
        case extSystemId = "ext_systemid"
        case hasReceipt = "has_receipt"
        case hasTaxFields = "has_tax_fields"
        case includeReceipt = "include_receipt"
        case invoiceId = "invoiceid"
        case isDuplicate = "is_duplicate"
        case markupPercent = "markup_percent"
        case modernProjectId = "modern_projectid"
        case notes
        case profileId = "profileid"
        case projectId = "projectid"
        case staffId = "staffid"
        case status
        case taxAmount1 = "taxAmount1"
        case taxAmount2 = "taxAmount2"
        case taxName1 = "taxName1"
        case taxName2 = "taxName2"
        case taxPercent1 = "taxPercent1"
        case taxPercent2 = "taxPercent2"
        case transactionId = "transactionid"
        case updated
        case vendor
        case vendorId = "vendorid"
        case visState = "vis_state"
    }
}

/// Detailed expense response with attachment info
struct FBExpenseDetail: Codable {
    let id: Int
    let attachmentId: Int?
    let hasReceipt: Bool?
    let attachment: FBAttachment?

    enum CodingKeys: String, CodingKey {
        case id
        case attachmentId = "attachment_id"
        case hasReceipt = "has_receipt"
        case attachment
    }
}

struct FBAttachment: Codable {
    let id: Int?
    let jwt: String?
    let mediaType: String?
    let fileName: String?
    let uuid: String?

    enum CodingKeys: String, CodingKey {
        case id
        case jwt
        case mediaType = "media_type"
        case fileName = "file_name"
        case uuid
    }
}
