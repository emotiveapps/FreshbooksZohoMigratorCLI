import Foundation

struct FBPaymentResponse: Codable {
    let response: FBPaymentResponseBody
}

struct FBPaymentResponseBody: Codable {
    let result: FBPaymentResult
}

struct FBPaymentResult: Codable {
    let payments: [FBPayment]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case payments
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}

struct FBPayment: Codable, Identifiable {
    let id: Int
    let accountingSystemId: String?
    let amount: FBMoney?
    let clientId: Int?
    let creditId: Int?
    let date: String?
    let fromCredit: Bool?
    let gateway: String?
    let invoiceId: Int?
    let note: String?
    let orderId: String?
    let overpaymentId: Int?
    let transactionId: String?
    let type: String?
    let updated: String?
    let visState: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case accountingSystemId = "accounting_systemid"
        case amount
        case clientId = "clientid"
        case creditId = "creditid"
        case date
        case fromCredit = "from_credit"
        case gateway
        case invoiceId = "invoiceid"
        case note
        case orderId = "orderid"
        case overpaymentId = "overpaymentid"
        case transactionId = "transactionid"
        case type
        case updated
        case visState = "vis_state"
    }

    var displayName: String {
        if let note = note, !note.isEmpty {
            return note
        }
        if let date = date {
            return "Payment on \(date)"
        }
        return "Payment \(id)"
    }

    var amountValue: Double? {
        guard let amount = amount, let amountStr = amount.amount else { return nil }
        return Double(amountStr)
    }
}
