import Foundation

struct FBInvoiceResponse: Codable {
    let response: FBInvoiceResponseBody
}

struct FBInvoiceResponseBody: Codable {
    let result: FBInvoiceResult
}

struct FBInvoiceResult: Codable {
    let invoices: [FBInvoice]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case invoices
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}

struct FBInvoice: Codable, Identifiable {
    let id: Int
    let invoiceId: Int?
    let accountId: String?
    let accountingSystemId: String?
    let address: String?
    let amount: FBMoney?
    let autoBill: Bool?
    let autobillStatus: String?
    let city: String?
    let code: String?
    let country: String?
    let createDate: String?
    let currencyCode: String?
    let currentOrganization: String?
    let customerId: Int?
    let dateGenerated: String?
    let depositAmount: FBMoney?
    let depositPercentage: String?
    let depositStatus: String?
    let description: String?
    let discountDescription: String?
    let discountTotal: FBMoney?
    let discountValue: String?
    let displayStatus: String?
    let disputeStatus: String?
    let dueDate: String?
    let dueOffsetDays: Int?
    let estimateId: Int?
    let extArchive: Int?
    let fname: String?
    let fulfillmentDate: String?
    let generationDate: String?
    let invoiceNumber: String?
    let language: String?
    let lastOrderStatus: String?
    let lines: [FBInvoiceLine]?
    let lname: String?
    let notes: String?
    let organization: String?
    let outstanding: FBMoney?
    let ownerid: Int?
    let paid: FBMoney?
    let parentId: Int?
    let paymentDetails: String?
    let paymentStatus: String?
    let poNumber: String?
    let province: String?
    let returnUri: String?
    let sentid: Int?
    let showAttachments: Bool?
    let status: Int?
    let street: String?
    let street2: String?
    let template: String?
    let terms: String?
    let updated: String?
    let v3Status: String?
    let vatName: String?
    let vatNumber: String?
    let visState: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case invoiceId = "invoiceid"
        case accountId = "accountid"
        case accountingSystemId = "accounting_systemid"
        case address
        case amount
        case autoBill = "auto_bill"
        case autobillStatus = "autobill_status"
        case city
        case code
        case country
        case createDate = "create_date"
        case currencyCode = "currency_code"
        case currentOrganization = "current_organization"
        case customerId = "customerid"
        case dateGenerated = "date_generated"
        case depositAmount = "deposit_amount"
        case depositPercentage = "deposit_percentage"
        case depositStatus = "deposit_status"
        case description
        case discountDescription = "discount_description"
        case discountTotal = "discount_total"
        case discountValue = "discount_value"
        case displayStatus = "display_status"
        case disputeStatus = "dispute_status"
        case dueDate = "due_date"
        case dueOffsetDays = "due_offset_days"
        case estimateId = "estimateid"
        case extArchive = "ext_archive"
        case fname
        case fulfillmentDate = "fulfillment_date"
        case generationDate = "generation_date"
        case invoiceNumber = "invoice_number"
        case language
        case lastOrderStatus = "last_order_status"
        case lines
        case lname
        case notes
        case organization
        case outstanding
        case ownerid
        case paid
        case parentId = "parent"
        case paymentDetails = "payment_details"
        case paymentStatus = "payment_status"
        case poNumber = "po_number"
        case province
        case returnUri = "return_uri"
        case sentid
        case showAttachments = "show_attachments"
        case status
        case street
        case street2
        case template
        case terms
        case updated
        case v3Status = "v3_status"
        case vatName = "vat_name"
        case vatNumber = "vat_number"
        case visState = "vis_state"
    }
}

struct FBInvoiceLine: Codable {
    let lineId: Int?
    let amount: FBMoney?
    let basecampId: Int?
    let compoundedTax: Bool?
    let date: String?
    let description: String?
    let expenseId: Int?
    let invoiceId: Int?
    let name: String?
    let qty: String?
    let retainerId: Int?
    let retainerPeriodId: Int?
    let taskno: Int?
    let taxAmount1: String?
    let taxAmount2: String?
    let taxName1: String?
    let taxName2: String?
    let taxNumber1: String?
    let taxNumber2: String?
    let type: Int?
    let unitCost: FBMoney?
    let updated: String?

    enum CodingKeys: String, CodingKey {
        case lineId = "lineid"
        case amount
        case basecampId = "basecampid"
        case compoundedTax = "compounded_tax"
        case date
        case description
        case expenseId = "expenseid"
        case invoiceId = "invoiceid"
        case name
        case qty
        case retainerId = "retainerid"
        case retainerPeriodId = "retainer_period_id"
        case taskno
        case taxAmount1 = "taxAmount1"
        case taxAmount2 = "taxAmount2"
        case taxName1 = "taxName1"
        case taxName2 = "taxName2"
        case taxNumber1 = "taxNumber1"
        case taxNumber2 = "taxNumber2"
        case type
        case unitCost = "unit_cost"
        case updated
    }
}

struct FBMoney: Codable {
    let amount: String?
    let code: String?
}
