import Foundation

struct ZBInvoiceResponse: Codable {
    let code: Int
    let message: String
    let invoice: ZBInvoice?
}

struct ZBInvoiceListResponse: Codable {
    let code: Int
    let message: String
    let invoices: [ZBInvoice]?
}

struct ZBInvoice: Codable {
    var invoiceId: String?
    var invoiceNumber: String?
    var customerId: String?
    var customerName: String?
    var status: String?
    var date: String?
    var dueDate: String?
    var currencyId: String?
    var currencyCode: String?
    var total: Double?
    var balance: Double?
    var lineItems: [ZBInvoiceLineItem]?
    var notes: String?
    var terms: String?
    var paymentTerms: Int?
    var paymentTermsLabel: String?
    var isInclusiveTax: Bool?
    var referenceNumber: String?

    enum CodingKeys: String, CodingKey {
        case invoiceId = "invoice_id"
        case invoiceNumber = "invoice_number"
        case customerId = "customer_id"
        case customerName = "customer_name"
        case status
        case date
        case dueDate = "due_date"
        case currencyId = "currency_id"
        case currencyCode = "currency_code"
        case total
        case balance
        case lineItems = "line_items"
        case notes
        case terms
        case paymentTerms = "payment_terms"
        case paymentTermsLabel = "payment_terms_label"
        case isInclusiveTax = "is_inclusive_tax"
        case referenceNumber = "reference_number"
    }
}

struct ZBInvoiceLineItem: Codable {
    var lineItemId: String?
    var itemId: String?
    var name: String?
    var description: String?
    var rate: Double?
    var quantity: Double?
    var unit: String?
    var taxId: String?
    var taxName: String?
    var taxPercentage: Double?
    var itemTotal: Double?

    enum CodingKeys: String, CodingKey {
        case lineItemId = "line_item_id"
        case itemId = "item_id"
        case name
        case description
        case rate
        case quantity
        case unit
        case taxId = "tax_id"
        case taxName = "tax_name"
        case taxPercentage = "tax_percentage"
        case itemTotal = "item_total"
    }
}

struct ZBInvoiceCreateRequest: Codable {
    var customerId: String
    var invoiceNumber: String?
    var referenceNumber: String?
    var date: String?
    var dueDate: String?
    var currencyCode: String?
    var lineItems: [ZBInvoiceLineItemRequest]
    var notes: String?
    var terms: String?
    var paymentTerms: Int?
    var isInclusiveTax: Bool?

    enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case invoiceNumber = "invoice_number"
        case referenceNumber = "reference_number"
        case date
        case dueDate = "due_date"
        case currencyCode = "currency_code"
        case lineItems = "line_items"
        case notes
        case terms
        case paymentTerms = "payment_terms"
        case isInclusiveTax = "is_inclusive_tax"
    }
}

struct ZBInvoiceLineItemRequest: Codable {
    var name: String?
    var description: String?
    var rate: Double?
    var quantity: Double?
    var taxId: String?
    var isTaxable: Bool?
    var taxExemptionId: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case rate
        case quantity
        case taxId = "tax_id"
        case isTaxable = "is_taxable"
        case taxExemptionId = "tax_exemption_id"
    }
}
