import Foundation

struct InvoiceMapper {
    static func map(_ invoice: FBInvoice, customerIdMapping: [Int: String]) -> ZBInvoiceCreateRequest? {
        guard let customerId = invoice.customerId,
              let zohoCustomerId = customerIdMapping[customerId] else {
            return nil
        }

        var lineItems: [ZBInvoiceLineItemRequest] = []
        if let lines = invoice.lines {
            for line in lines {
                let rate: Double
                if let unitCost = line.unitCost?.amount, let value = Double(unitCost) {
                    rate = value
                } else {
                    rate = 0
                }

                let quantity: Double
                if let qty = line.qty, let value = Double(qty) {
                    quantity = value
                } else {
                    quantity = 1
                }

                lineItems.append(ZBInvoiceLineItemRequest(
                    name: line.name ?? "Item",
                    description: line.description,
                    rate: rate,
                    quantity: quantity
                ))
            }
        }

        if lineItems.isEmpty {
            if let amount = invoice.amount?.amount, let value = Double(amount) {
                lineItems.append(ZBInvoiceLineItemRequest(
                    name: "Invoice Total",
                    description: invoice.description,
                    rate: value,
                    quantity: 1
                ))
            }
        }

        return ZBInvoiceCreateRequest(
            customerId: zohoCustomerId,
            invoiceNumber: invoice.invoiceNumber,
            referenceNumber: invoice.poNumber,
            date: invoice.createDate,
            dueDate: invoice.dueDate,
            currencyCode: invoice.currencyCode,
            lineItems: lineItems,
            notes: invoice.notes,
            terms: invoice.terms,
            paymentTerms: nil,
            isInclusiveTax: false
        )
    }
}
