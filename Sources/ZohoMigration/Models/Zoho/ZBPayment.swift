import Foundation

struct ZBPaymentResponse: Codable {
    let code: Int
    let message: String
    let payment: ZBPayment?
}

struct ZBPaymentListResponse: Codable {
    let code: Int
    let message: String
    let customerpayments: [ZBPayment]?
}

struct ZBPayment: Codable {
    var paymentId: String?
    var customerId: String?
    var invoices: [ZBPaymentInvoice]?
    var paymentMode: String?
    var amount: Double?
    var bankCharges: Double?
    var date: String?
    var referenceNumber: String?
    var description: String?
    var accountId: String?

    enum CodingKeys: String, CodingKey {
        case paymentId = "payment_id"
        case customerId = "customer_id"
        case invoices
        case paymentMode = "payment_mode"
        case amount
        case bankCharges = "bank_charges"
        case date
        case referenceNumber = "reference_number"
        case description
        case accountId = "account_id"
    }
}

struct ZBPaymentInvoice: Codable {
    var invoiceId: String
    var amountApplied: Double

    enum CodingKeys: String, CodingKey {
        case invoiceId = "invoice_id"
        case amountApplied = "amount_applied"
    }
}

struct ZBPaymentCreateRequest: Codable {
    var customerId: String
    var invoices: [ZBPaymentInvoice]?
    var paymentMode: String?
    var amount: Double
    var date: String
    var referenceNumber: String?
    var description: String?
    var accountId: String?

    enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case invoices
        case paymentMode = "payment_mode"
        case amount
        case date
        case referenceNumber = "reference_number"
        case description
        case accountId = "account_id"
    }
}
