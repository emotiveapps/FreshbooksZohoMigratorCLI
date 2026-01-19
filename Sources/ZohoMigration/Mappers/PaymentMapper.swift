import Foundation

struct PaymentMapperResult {
    let request: ZBPaymentCreateRequest
    let depositAccountMapped: Bool
    let unmappedKey: String?  // gateway or type that wasn't mapped
}

struct PaymentMapper {
    static func map(
        _ payment: FBPayment,
        customerIdMapping: [Int: String],
        invoiceIdMapping: [Int: String] = [:],
        depositAccountMapping: [String: String] = [:]  // gateway/type (lowercased) -> Zoho accountId
    ) -> PaymentMapperResult? {
        guard let clientId = payment.clientId,
              let customerId = customerIdMapping[clientId] else {
            return nil
        }

        guard let amountValue = payment.amountValue, amountValue > 0 else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = payment.date ?? dateFormatter.string(from: Date())

        var invoices: [ZBPaymentInvoice]?
        if let invoiceId = payment.invoiceId,
           let zohoInvoiceId = invoiceIdMapping[invoiceId] {
            invoices = [ZBPaymentInvoice(invoiceId: zohoInvoiceId, amountApplied: amountValue)]
        }

        var paymentMode: String?
        if let gateway = payment.gateway {
            paymentMode = mapPaymentGateway(gateway)
        } else if let type = payment.type {
            paymentMode = mapPaymentType(type)
        }

        // Determine deposit account based on gateway or type
        var accountId: String? = nil
        var depositAccountMapped = false
        var unmappedKey: String? = nil

        if let gateway = payment.gateway?.lowercased() {
            if let mapped = depositAccountMapping[gateway] {
                accountId = mapped
                depositAccountMapped = true
            } else {
                unmappedKey = payment.gateway
            }
        }
        if accountId == nil, let type = payment.type?.lowercased() {
            if let mapped = depositAccountMapping[type] {
                accountId = mapped
                depositAccountMapped = true
            } else if unmappedKey == nil {
                unmappedKey = payment.type
            }
        }
        if accountId == nil {
            accountId = depositAccountMapping["default"]
            // Still not mapped if we fell through to default
        }

        let request = ZBPaymentCreateRequest(
            customerId: customerId,
            invoices: invoices,
            paymentMode: paymentMode,
            amount: amountValue,
            date: date,
            referenceNumber: payment.transactionId ?? payment.orderId,
            description: payment.note,
            accountId: accountId
        )

        return PaymentMapperResult(
            request: request,
            depositAccountMapped: depositAccountMapped,
            unmappedKey: unmappedKey
        )
    }

    private static func mapPaymentGateway(_ gateway: String) -> String {
        switch gateway.lowercased() {
        case "stripe":
            return "credit_card"
        case "paypal":
            return "paypal"
        case "square":
            return "credit_card"
        case "wepay":
            return "bank_transfer"
        case "2checkout":
            return "credit_card"
        default:
            return "cash"
        }
    }

    private static func mapPaymentType(_ type: String) -> String {
        switch type.lowercased() {
        case "credit":
            return "credit_card"
        case "check", "cheque":
            return "check"
        case "cash":
            return "cash"
        case "bank transfer", "ach":
            return "bank_transfer"
        default:
            return "cash"
        }
    }
}
